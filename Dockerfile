# To enable ssh & remote debugging on app service change the base image to the one below
# FROM mcr.microsoft.com/azure-functions/node:4-node20-appservice
FROM mcr.microsoft.com/azure-functions/node:4-node20

ENV AzureWebJobsScriptRoot=/home/site/wwwroot \
    AzureFunctionsJobHost__Logging__Console__IsEnabled=true

WORKDIR /home/site/wwwroot

# Copy package.json and install packages before copying the rest of the code to enable caching
# Copy package.json first for layer caching
COPY package.json package.json

# Install a prebuilt/static wkhtmltopdf package (official release) and minimal font support.
# Using the official .deb (prebuilt with patched Qt) keeps runtime light and cold starts faster
# than building or pulling many runtime Qt libs manually.
ENV WKHTMLTOPDF_VERSION=0.12.6
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates wget fontconfig fonts-dejavu-core; \
    # Download the official prebuilt Debian package (amd64). This package contains a patched Qt
    # and the wkhtmltopdf binary. If you need a different version, update the URL accordingly.
    wget -q -O /tmp/wkhtmltox.deb "https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.6/wkhtmltox_0.12.6-1.bionic_amd64.deb"; \
    apt-get install -y --no-install-recommends /tmp/wkhtmltox.deb; \
    rm -f /tmp/wkhtmltox.deb; \
    rm -rf /var/lib/apt/lists/*;

RUN npm install

# Copy the rest of the code
COPY . .