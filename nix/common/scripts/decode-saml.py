# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "defusedxml",
# ]
# ///

import sys
import zlib
import base64
import urllib.parse
import argparse
from defusedxml.minidom import parseString

def decode_saml(input_data: str) -> str:
    """
    Decodes a SAMLRequest/SAMLResponse from a URL or raw string.
    Follows: URL Decode -> Base64 Decode -> Inflate (Raw)
    """
    # 1. Handle full URLs by extracting the query parameter
    parsed_url = urllib.parse.urlparse(input_data)
    query_params = urllib.parse.parse_qs(parsed_url.query)

    # Check for common SAML parameters in URLs
    encoded_str = input_data
    for param in ['SAMLRequest', 'SAMLResponse']:
        if param in query_params:
            encoded_str = query_params[param][0]
            break

    # 2. URL Decode (handles %2B -> +, etc.)
    url_decoded = urllib.parse.unquote(encoded_str)

    # 3. Base64 Decode
    try:
        b64_decoded = base64.b64decode(url_decoded)
    except Exception as e:
        raise ValueError(f"Failed to base64 decode: {e}")

    # 4. Decompress (Inflate)
    # SAML HTTP-Redirect uses raw DEFLATE (no zlib headers).
    # -15 window bits is the convention for raw deflate.
    try:
        decompressed = zlib.decompress(b64_decoded, -15)
    except zlib.error:
        # Fallback: If it's an HTTP-POST binding, it might not be compressed.
        # We try to use the raw b64_decoded data if decompression fails.
        decompressed = b64_decoded

    # 5. Format and Return (Safe XML parsing)
    try:
        xml_str = decompressed.decode('utf-8')
        dom = parseString(xml_str)
        return dom.toprettyxml(indent="  ")
    except Exception as e:
        raise ValueError(f"Failed to parse XML: {e}. (Data might not be compressed/encoded correctly)")

def main():
    parser = argparse.ArgumentParser(description="Decode SAML Redirect binding payloads.")
    parser.add_argument("payload", help="The full URL or the encoded SAML string.")

    args = parser.parse_args()

    try:
        print(decode_saml(args.payload))
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
