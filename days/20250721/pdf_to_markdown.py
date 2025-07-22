#!/usr/bin/env python3
"""
PDF to Markdown Converter

This script converts PDF files to Markdown format using PyMuPDF (fitz).
It extracts text from each page and formats it as Markdown.

Requirements:
    pip install PyMuPDF

Usage:
    python pdf_to_markdown.py input.pdf [output.md]
"""

import sys
import argparse
from pathlib import Path
import fitz  # PyMuPDF
import pytesseract
from PIL import Image
import io


def extract_text_from_pdf(pdf_path):
    """Extract text from PDF file and return as string."""
    try:
        doc = fitz.open(pdf_path)
        text_content = []
        
        for page_num in range(len(doc)):
            page = doc.load_page(page_num)
            text = page.get_text()
            
            if text.strip():
                text_content.append(f"## Page {page_num + 1}\n\n{text}\n")
            else:
                # If no text found, try OCR on the page image
                print(f"No text found on page {page_num + 1}, attempting OCR...")
                pix = page.get_pixmap()
                img_data = pix.tobytes("png")
                img = Image.open(io.BytesIO(img_data))
                
                try:
                    ocr_text = pytesseract.image_to_string(img)
                    if ocr_text.strip():
                        text_content.append(f"## Page {page_num + 1}\n\n{ocr_text}\n")
                except Exception as ocr_error:
                    print(f"OCR failed for page {page_num + 1}: {ocr_error}")
        
        doc.close()
        return "\n".join(text_content)
    
    except Exception as e:
        raise RuntimeError(f"Error reading PDF: {e}")


def clean_text_for_markdown(text):
    """Clean and format text for better Markdown output."""
    lines = text.split('\n')
    cleaned_lines = []
    
    for line in lines:
        line = line.strip()
        if line:
            if line.isupper() and len(line.split()) <= 10:
                cleaned_lines.append(f"### {line}\n")
            else:
                cleaned_lines.append(line)
        else:
            cleaned_lines.append("")
    
    return '\n'.join(cleaned_lines)


def convert_pdf_to_markdown(input_path, output_path=None):
    """Convert PDF to Markdown file."""
    input_file = Path(input_path)
    
    if not input_file.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")
    
    if not input_file.suffix.lower() == '.pdf':
        raise ValueError("Input file must be a PDF")
    
    if output_path is None:
        output_path = input_file.with_suffix('.md')
    else:
        output_path = Path(output_path)
    
    print(f"Converting {input_file} to {output_path}...")
    
    raw_text = extract_text_from_pdf(input_path)
    
    if not raw_text.strip():
        raise RuntimeError("No text content found in PDF")
    
    markdown_content = f"# {input_file.stem}\n\n"
    markdown_content += f"*Converted from PDF: {input_file.name}*\n\n"
    markdown_content += "---\n\n"
    markdown_content += clean_text_for_markdown(raw_text)
    
    output_path.write_text(markdown_content, encoding='utf-8')
    
    print(f"✓ Conversion complete: {output_path}")
    return output_path


def main():
    parser = argparse.ArgumentParser(description='Convert PDF files to Markdown format')
    parser.add_argument('input', help='Input PDF file path')
    parser.add_argument('output', nargs='?', help='Output Markdown file path (optional)')
    
    args = parser.parse_args()
    
    try:
        convert_pdf_to_markdown(args.input, args.output)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()