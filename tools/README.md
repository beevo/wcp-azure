This folder contains a small helper script `convert_and_upload.py`.

Usage example (local test):

1. Build the image (amd64 for Azure):

   docker buildx build --platform linux/amd64 --load -t wkhtmltopdf-func:0.12.6 /Users/bvo/code/wcp-azure

2. Run the helper inside the container (will fetch HTML, convert to PDF, then POST it):

   docker run --rm wkhtmltopdf-func:0.12.6 \
     python /usr/local/bin/convert_and_upload.py \
     --source "https://qc.wcpsolutions.com/" \
     --upload "https://qc.wcpsolutions.com/your-upload-endpoint"

Note: the upload endpoint must accept a multipart POST with the file field named `file` by default.
