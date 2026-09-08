# Standards and Conformance Matrix

MoonMIME implements a bounded v0.1 subset rather than claiming complete mail-user-agent conformance.

| Standard | Implemented subset | Explicit gap |
|---|---|---|
| RFC 5322 | header/body separator, field names, folding/unfolding, ordered duplicates | address/date/message-id semantic parsers |
| RFC 2045 | transfer-encoding field, 7bit/8bit/binary identity, Base64, Quoted-Printable | full MIME-Version conformance policy |
| RFC 2046 | media type, multipart boundary, preamble/epilogue, recursive parts, message/rfc822 | partial/external-body and subtype-specific policies |
| RFC 2047 | B/Q encoded-words, adjacent-word whitespace, three character sets | arbitrary charset conversion and encoded-word use in every structured field |
| RFC 2183 | Content-Disposition token and parameters | disposition-date semantics |
| RFC 2231 | charset/language prefix, percent encoding, numbered continuation | language selection policy and arbitrary charset conversion |

Primary references:

- <https://datatracker.ietf.org/doc/html/rfc5322>
- <https://datatracker.ietf.org/doc/html/rfc2045>
- <https://datatracker.ietf.org/doc/html/rfc2046>
- <https://datatracker.ietf.org/doc/html/rfc2047>
- <https://datatracker.ietf.org/doc/html/rfc2183>
- <https://datatracker.ietf.org/doc/html/rfc2231>

Tests and examples are independently authored synthetic inputs. The RFC text is not copied into implementation source.
