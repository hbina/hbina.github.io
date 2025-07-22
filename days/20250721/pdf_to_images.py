#!/usr/bin/env python3
"""
PDF to Images Converter

This script converts PDF pages to PNG images when text extraction fails.
Useful for scanned PDFs or image-based documents.

Usage:
    python pdf_to_images.py input.pdf [output_dir]
"""

import sys
import argparse
from pathlib import Path
import fitz  # PyMuPDF


def pdf_to_images(pdf_path, output_dir=None):
    """Convert PDF pages to PNG images."""
    input_file = Path(pdf_path)
    
    if not input_file.exists():
        raise FileNotFoundError(f"Input file not found: {pdf_path}")
    
    if output_dir is None:
        output_dir = input_file.parent / f"{input_file.stem}_images"
    else:
        output_dir = Path(output_dir)
    
    output_dir.mkdir(exist_ok=True)
    
    doc = fitz.open(pdf_path)
    
    print(f"Converting {len(doc)} pages to images in {output_dir}")
    
    for page_num in range(len(doc)):
        page = doc.load_page(page_num)
        pix = page.get_pixmap(matrix=fitz.Matrix(2.0, 2.0))  # 2x zoom for better quality
        
        output_file = output_dir / f"page_{page_num + 1:03d}.png"
        pix.save(str(output_file))
        print(f"✓ Page {page_num + 1} saved as {output_file}")
    
    doc.close()
    print(f"\nAll pages converted to images in: {output_dir}")
    return output_dir


def main():
    parser = argparse.ArgumentParser(description='Convert PDF pages to PNG images')
    parser.add_argument('input', help='Input PDF file path')
    parser.add_argument('output_dir', nargs='?', help='Output directory for images (optional)')
    
    args = parser.parse_args()
    
    try:
        pdf_to_images(args.input, args.output_dir)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()