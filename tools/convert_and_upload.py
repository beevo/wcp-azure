#!/usr/bin/env python3
"""
Download HTML from a URL, convert to PDF using wkhtmltopdf, and POST the PDF to an upload URL.
Usage:
  python /usr/local/bin/convert_and_upload.py --source https://qc.wcpsolutions.com/ --upload https://qc.wcpsolutions.com/upload-endpoint

The script writes temporary files and cleans them up. It exits non-zero on failure.
"""
import argparse
import requests
import subprocess
import tempfile
import os
import sys
import time


def run(cmd):
    proc = subprocess.run(cmd, shell=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return proc.returncode, proc.stdout, proc.stderr


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--source', '-s', default='https://qc.wcpsolutions.com/public/product-guide.html', help='Source HTML URL')
    p.add_argument('--upload', '-u', default='https://qc.wcpsolutions.com/public/product-guide.php', help='Upload endpoint URL (POST)')
    p.add_argument('--upload-field', default='pdf', help='Form field name for the uploaded file')
    p.add_argument('--timeout', type=int, default=30, help='Timeout for HTTP requests')
    args = p.parse_args()

    try:
        r = requests.get(args.source, timeout=args.timeout)
        r.raise_for_status()
    except Exception as e:
        print(f"Error fetching source URL {args.source}: {e}", file=sys.stderr)
        sys.exit(2)

    with tempfile.TemporaryDirectory() as tmpdir:
        html_path = os.path.join(tmpdir, 'page.html')
        timestamp = int(time.time())
        pdf_filename = f'ppg-{timestamp}.pdf'
        pdf_path = os.path.join(tmpdir, pdf_filename)
        with open(html_path, 'wb') as f:
            f.write(r.content)

        # Convert to PDF using wkhtmltopdf
        cmd = ['/usr/bin/wkhtmltopdf', html_path, pdf_path]
        code, out, err = run(cmd)
        if code != 0:
            print('wkhtmltopdf failed', file=sys.stderr)
            print(err.decode('utf-8', errors='replace'), file=sys.stderr)
            sys.exit(3)

        # Upload PDF
        files = {args.upload_field: (pdf_filename, open(pdf_path, 'rb'), 'application/pdf')}
        try:
            resp = requests.post(args.upload, files=files, timeout=args.timeout)
            resp.raise_for_status()
        except Exception as e:
            print(f"Upload failed: {e}", file=sys.stderr)
            # show server response if any
            try:
                print('Response status:', getattr(resp, 'status_code', None), file=sys.stderr)
                print(getattr(resp, 'text', ''), file=sys.stderr)
            except Exception:
                pass
            sys.exit(4)

        print('Upload succeeded, status', resp.status_code)
        print(resp.text)


if __name__ == '__main__':
    main()
