"""Print a picture (CUPS printers through Qt Print Support) or save it as a PDF.

The print sheet in QML (components/PrintDialog.qml) collects the options; the job itself
runs in a worker thread (QPainter on a QPrinter is thread-safe).
"""

import logging
import os

from PIL import Image, ImageOps
from PySide6.QtCore import QMarginsF, QRectF, QSizeF
from PySide6.QtGui import QImage, QPageLayout, QPageSize, QPainter

from .thumbs import _to_qimage

log = logging.getLogger(__name__)

try:
    from PySide6.QtPrintSupport import QPrinter, QPrinterInfo
    AVAILABLE = True
except ImportError:  # PySide6 built without Qt Print Support
    QPrinter = QPrinterInfo = None
    AVAILABLE = False

PDF = "__pdf__"     # pseudo printer: write a PDF file
DPI = 300           # enough detail for photo paper, keeps jobs small
MARGIN_MM = 5

# id -> (label, QPageSize id or (width mm, height mm))
PAPERS = {
    "a4": ("A4", QPageSize.A4),
    "letter": ("Letter", QPageSize.Letter),
    "a5": ("A5", QPageSize.A5),
    "a3": ("A3", QPageSize.A3),
    "legal": ("Legal", QPageSize.Legal),
    "10x15": ("10 × 15 cm (4 × 6 in)", (101.6, 152.4)),
    "13x18": ("13 × 18 cm (5 × 7 in)", (127.0, 177.8)),
}


def page_size(paper: str) -> QPageSize:
    label, spec = PAPERS.get(paper, PAPERS["a4"])
    if isinstance(spec, tuple):
        return QPageSize(QSizeF(*spec), QPageSize.Millimeter, label)
    return QPageSize(spec)


def default_paper() -> str:
    """Paper of the default printer when it is one we offer, else Letter/A4 by locale."""
    if AVAILABLE:
        try:
            pid = QPrinterInfo.defaultPrinter().defaultPageSize().id()
            for key, (_label, spec) in PAPERS.items():
                if not isinstance(spec, tuple) and spec == pid:
                    return key
        except Exception:
            pass
    from PySide6.QtCore import QLocale
    return "letter" if QLocale().measurementSystem() != QLocale.MetricSystem else "a4"


def printers() -> list[dict]:
    """Installed printers (default first) plus "Save as PDF". Runs in a worker."""
    found = []
    if AVAILABLE:
        try:
            default = QPrinterInfo.defaultPrinterName()
            for info in QPrinterInfo.availablePrinters():
                name = info.printerName()
                found.append({"id": name, "name": info.description() or name,
                              "detail": info.location() or info.makeAndModel(),
                              "isDefault": name == default, "pdf": False})
        except Exception as exc:
            log.info("cannot list printers: %s", exc)
    found.sort(key=lambda p: (not p["isDefault"], p["name"].lower()))
    found.append({"id": PDF, "name": "Save as PDF", "detail": "", "isDefault": not found, "pdf": True})
    return found


def papers() -> list[dict]:
    return [{"value": k, "label": v[0]} for k, v in PAPERS.items()]


def _load(path: str, max_w: int, max_h: int, gray: bool) -> Image.Image:
    with Image.open(path) as im:
        im.draft("RGB", (max_w, max_h))
        im = ImageOps.exif_transpose(im)
        im.load()
    if im.width > max_w or im.height > max_h:
        im.thumbnail((max_w, max_h), Image.LANCZOS)
    return im.convert("L").convert("RGB") if gray else im


def target_rect(img_w, img_h, area: QRectF, fill: bool) -> tuple[QRectF, QRectF]:
    """(target on the page, source rect in the image) for fit or fill."""
    page_ar, img_ar = area.width() / area.height(), img_w / img_h
    if fill:  # cover the area, crop the picture around its centre
        if img_ar > page_ar:
            sw = img_h * page_ar
            return area, QRectF((img_w - sw) / 2, 0, sw, img_h)
        sh = img_w / page_ar
        return area, QRectF(0, (img_h - sh) / 2, img_w, sh)
    if img_ar > page_ar:
        h = area.width() / img_ar
        return QRectF(area.x(), area.y() + (area.height() - h) / 2, area.width(), h), QRectF(0, 0, img_w, img_h)
    w = area.height() * img_ar
    return QRectF(area.x() + (area.width() - w) / 2, area.y(), w, area.height()), QRectF(0, 0, img_w, img_h)


def print_image(path: str, opts: dict) -> str:
    """Print (or save as PDF) one picture. Returns a message for the user. Runs in a worker.

    opts: printer (id or PDF), pdfPath, paper, orientation (auto/portrait/landscape),
          fill (bool), borderless (bool), gray (bool), copies (int)."""
    if not AVAILABLE:
        raise RuntimeError("Printing needs Qt Print Support (part of pyside6)")
    printer_id = opts.get("printer") or PDF
    to_pdf = printer_id == PDF
    with Image.open(path) as probe:
        w, h = probe.size
        if probe.getexif().get(274, 1) in (5, 6, 7, 8):  # stored sideways
            w, h = h, w
    orientation = opts.get("orientation", "auto")
    landscape = (w > h) if orientation == "auto" else orientation == "landscape"

    printer = QPrinter(QPrinter.HighResolution)
    if to_pdf:
        out = opts.get("pdfPath") or os.path.splitext(path)[0] + ".pdf"
        printer.setOutputFormat(QPrinter.PdfFormat)
        printer.setOutputFileName(out)
    else:
        # Qt silently falls back to the default printer for an unknown name (on Windows
        # often "Microsoft Print to PDF", which then waits on a hidden Save dialog)
        if printer_id not in QPrinterInfo.availablePrinterNames():
            raise RuntimeError(f"Printer {printer_id} is not available")
        printer.setPrinterName(printer_id)
        if not printer.isValid():
            raise RuntimeError(f"Printer {printer_id} is not available")
    printer.setDocName(os.path.basename(path))
    printer.setCopyCount(max(1, min(99, int(opts.get("copies", 1)))))
    gray = bool(opts.get("gray"))
    printer.setColorMode(QPrinter.GrayScale if gray else QPrinter.Color)
    borderless = bool(opts.get("borderless"))
    margins = QMarginsF(0, 0, 0, 0) if borderless else QMarginsF(MARGIN_MM, MARGIN_MM, MARGIN_MM, MARGIN_MM)
    layout = QPageLayout(page_size(opts.get("paper", "a4")),
                         QPageLayout.Landscape if landscape else QPageLayout.Portrait,
                         margins, QPageLayout.Millimeter)
    printer.setPageLayout(layout)
    printer.setFullPage(borderless)

    painter = QPainter()
    if not painter.begin(printer):
        raise RuntimeError("Can't start the print job" if not to_pdf else "Can't write the PDF")
    try:
        dev = painter.device()
        area = QRectF(0, 0, dev.width(), dev.height())
        # decode only as many pixels as DPI needs on this area
        scale = DPI / max(1, printer.resolution())
        im = _load(path, int(area.width() * scale) + 1, int(area.height() * scale) + 1, gray)
        qimg: QImage = _to_qimage(im)
        target, source = target_rect(qimg.width(), qimg.height(), area, bool(opts.get("fill")))
        painter.setRenderHint(QPainter.SmoothPixmapTransform, True)
        painter.drawImage(target, qimg, source)
    finally:
        painter.end()
    if to_pdf:
        return f"Saved {os.path.basename(printer.outputFileName())}"
    copies = printer.copyCount()
    return f"Sent to {opts.get('printerName') or printer_id}" + (f" ({copies} copies)" if copies > 1 else "")
