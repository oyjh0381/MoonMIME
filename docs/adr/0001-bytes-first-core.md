# Keep the parsing core bytes-first

MoonMIME accepts and retains `Bytes`, exposes source ranges, and derives decoded
payloads separately. Email bodies and attachments are not inherently text;
making `String` the source representation would corrupt arbitrary octets and
make exact auditing or re-emission impossible. Platform file I/O therefore
stays outside the portable parsing core.

