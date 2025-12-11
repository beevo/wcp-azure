# Use the Azure Functions Python base so the Functions host remains PID 1
FROM mcr.microsoft.com/azure-functions/python:4-python3.11

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies required by wkhtmltopdf
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       wget \
       gnupg2 \
       xfonts-75dpi \
       xfonts-base \
       fontconfig \
       libfreetype6 \
       libjpeg62-turbo \
       libx11-6 \
       libxcb1 \
       libxext6 \
       libxrender1 \
       libssl1.1 \
    && rm -rf /var/lib/apt/lists/*

# Package selection (override with --build-arg if you want different release)
ARG WKHTML_VERSION=0.12.6-1
ARG WKHTML_DIST=buster
ARG WKHTML_PKG=wkhtmltox_${WKHTML_VERSION}.${WKHTML_DIST}_amd64.deb
ARG WKHTML_URL=https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTML_VERSION}/${WKHTML_PKG}

# Allow building from a local .deb (place it in the build context) or fall back to downloading
COPY ${WKHTML_PKG} /tmp/${WKHTML_PKG}

RUN set -eux; \
    if [ -f /tmp/${WKHTML_PKG} ]; then \
        echo "Installing local ${WKHTML_PKG}"; \
    else \
        echo "Local ${WKHTML_PKG} not found, downloading ${WKHTML_URL}"; \
        wget -O /tmp/${WKHTML_PKG} "${WKHTML_URL}" ; \
    fi; \
    dpkg -i /tmp/${WKHTML_PKG} || (apt-get update && apt-get install -y -f --no-install-recommends); \
    # Ensure binary reachable at /usr/bin/wkhtmltopdf
    if [ -x /usr/bin/wkhtmltopdf ]; then \
        true; \
    elif [ -x /usr/local/bin/wkhtmltopdf ]; then \
        ln -sf /usr/local/bin/wkhtmltopdf /usr/bin/wkhtmltopdf; \
    elif [ -x /opt/wkhtmltox/bin/wkhtmltopdf ]; then \
        ln -sf /opt/wkhtmltox/bin/wkhtmltopdf /usr/bin/wkhtmltopdf; \
    else \
        B=$(find / -type f -name wkhtmltopdf 2>/dev/null | head -n 1 || true); \
        if [ -n "$B" ]; then ln -sf "$B" /usr/bin/wkhtmltopdf; else echo 'warning: wkhtmltopdf binary not found after dpkg install' >&2; fi; \
    fi; \
    if command -v wkhtmltopdf >/dev/null 2>&1; then wkhtmltopdf --version || true; fi; \
    # Fail-fast during image build: ensure wkhtmltopdf exists and is executable
    if ! command -v wkhtmltopdf >/dev/null 2>&1; then \
        echo "ERROR: wkhtmltopdf binary not found after installation" >&2; \
        exit 1; \
    fi; \
    rm -f /tmp/${WKHTML_PKG}; \
    rm -rf /var/lib/apt/lists/*

# Install python dependencies for the helper script
RUN pip3 install --no-cache-dir requests

# Add helper script to image
COPY tools/convert_and_upload.py /usr/local/bin/convert_and_upload.py
RUN chmod +x /usr/local/bin/convert_and_upload.py

# Azure Functions app code root
WORKDIR /home/site/wwwroot

# IMPORTANT: Do not override ENTRYPOINT/CMD; leave the Functions host as PID 1

# Runtime healthcheck: verifies wkhtmltopdf responds (helps container orchestrators and CI)
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD sh -c "command -v wkhtmltopdf >/dev/null 2>&1 && wkhtmltopdf --version >/dev/null 2>&1 || exit 1"
