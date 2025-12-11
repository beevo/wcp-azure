import azure.functions as func
import subprocess
import json
import sys


def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    HTTP-triggered Azure Function that calls convert_and_upload.py
    
    Query parameters:
    - source: Source HTML URL (optional, uses script default)
    - upload: Upload endpoint URL (optional, uses script default)
    - upload_field: Form field name for PDF (optional, uses script default)
    - timeout: HTTP request timeout in seconds (optional, uses script default)
    
    Returns:
    - 200 OK with script output on success
    - 400 Bad Request if parameters are invalid
    - 500 Internal Server Error if script fails
    """
    
    try:
        # Build command line arguments from query params
        cmd = ['/usr/local/bin/convert_and_upload.py']
        
        source = req.params.get('source')
        if source:
            cmd.extend(['--source', source])
        
        upload = req.params.get('upload')
        if upload:
            cmd.extend(['--upload', upload])
        
        upload_field = req.params.get('upload_field')
        if upload_field:
            cmd.extend(['--upload-field', upload_field])
        
        timeout = req.params.get('timeout')
        if timeout:
            try:
                int(timeout)  # Validate it's a number
                cmd.extend(['--timeout', timeout])
            except ValueError:
                return func.HttpResponse(
                    json.dumps({'error': 'timeout must be an integer'}),
                    status_code=400,
                    mimetype='application/json'
                )
        
        # Run the conversion script
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        # Check exit code
        if result.returncode != 0:
            return func.HttpResponse(
                json.dumps({
                    'error': 'Conversion failed',
                    'exit_code': result.returncode,
                    'stderr': result.stderr
                }),
                status_code=500,
                mimetype='application/json'
            )
        
        # Return success with script output
        return func.HttpResponse(
            json.dumps({
                'success': True,
                'output': result.stdout
            }),
            status_code=200,
            mimetype='application/json'
        )
    
    except Exception as e:
        return func.HttpResponse(
            json.dumps({
                'error': str(e)
            }),
            status_code=500,
            mimetype='application/json'
        )
