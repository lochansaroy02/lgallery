"""Run a function on Qt's global thread pool and get the result back on the GUI thread."""

import logging
import traceback

from PySide6.QtCore import QObject, QRunnable, QThreadPool, Signal

log = logging.getLogger(__name__)

# Signal objects are kept alive here until their result has been delivered.
_pending: set = set()


class _Signals(QObject):
    done = Signal(object, object)  # result, error


class _Task(QRunnable):
    def __init__(self, fn, args, signals):
        super().__init__()
        self.fn = fn
        self.args = args
        self.signals = signals

    def run(self):
        try:
            result, error = self.fn(*self.args), None
        except Exception as exc:  # reported back, never raised in the pool
            if getattr(exc, "expected", False):  # e.g. a wrong password: no traceback
                log.info("background task: %s", exc)
            else:
                log.warning("background task failed: %s\n%s", exc, traceback.format_exc())
            result, error = None, exc
        self.signals.done.emit(result, error)


def run_async(fn, *args, on_done=None, on_error=None) -> None:
    """Call fn(*args) in a worker; on_done(result) / on_error(exc) run on the GUI thread.

    Must be called from the GUI thread so the signal object lives there.
    """
    signals = _Signals()
    _pending.add(signals)

    def deliver(result, error):
        _pending.discard(signals)
        signals.deleteLater()
        if error is not None:
            if on_error:
                on_error(error)
        elif on_done:
            on_done(result)

    signals.done.connect(deliver)
    QThreadPool.globalInstance().start(_Task(fn, args, signals))
