# MoonMIME

MoonMIME defines the domain language for interpreting an Internet message as a
byte-preserving tree of MIME entities.

## Language

**Internet Message**:
A complete RFC 5322-style byte sequence containing a header section and a body.
_Avoid_: Email string, mail blob

**Header Section**:
The ordered sequence of header fields before the empty line that separates it from the body.
_Avoid_: Metadata map, properties

**Header Field**:
One field name and its possibly folded raw value, retained in message order and without assuming names are unique.
_Avoid_: Header property, map entry

**MIME Entity**:
A header section and body interpreted together as one leaf, multipart container, or embedded Internet Message.
_Avoid_: Part, node

**Leaf Entity**:
A MIME Entity whose body is content rather than child entities.
_Avoid_: File part, attachment

**Multipart Entity**:
A MIME Entity whose boundary-delimited body contains ordered child MIME Entities.
_Avoid_: Folder, message list

**Embedded Message**:
An Internet Message carried by a `message/rfc822` MIME Entity.
_Avoid_: Nested attachment, forwarded string

**Raw Representation**:
The exact input bytes and byte ranges from which a parsed value originated.
_Avoid_: Source text, original string

**Decoded Payload**:
Bytes produced by applying a MIME content-transfer decoding to a Leaf Entity body.
_Avoid_: Decoded text, attachment string

**Display Text**:
Text obtained by applying an explicitly supported character set to a Decoded Payload.
_Avoid_: Body, decoded payload

**Parse Diagnostic**:
A structured observation about accepted non-standard input that does not invalidate the returned message.
_Avoid_: Error log, warning string

**Parse Failure**:
A structured reason that prevents the parser from returning a trustworthy Internet Message.
_Avoid_: Panic, generic error

**Payload Inventory**:
A byte-bound account of MIME entities with distinct encoded-region and decoded-content fingerprints; unavailable decoding remains explicit rather than implying empty or safe content.
_Avoid_: Extracted attachments, malware verdict

**Manifest Verification**:
Rechecking a supplied evidence manifest against its original message bytes, entity locations and derived metadata; it does not authenticate the acquisition or case identity.
_Avoid_: Signature verification, chain-of-custody certification

**Gateway Rule**:
A caller-owned restriction on declared attachment metadata or parser recovery, distinct from observations about syntax and content.
_Avoid_: MIME validity rule, antivirus signature

