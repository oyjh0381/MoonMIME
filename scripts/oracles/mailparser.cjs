// Development-only oracle. No MailParser implementation is copied into MoonMIME.
const fs = require('node:fs');
const crypto = require('node:crypto');
const { simpleParser } = require('mailparser');
(async () => {
  const mail = await simpleParser(fs.readFileSync(process.argv[2]), {
    skipHtmlToText: true, skipTextToHtml: true, skipImageLinks: true,
  });
  console.log(JSON.stringify({
    attachments: mail.attachments.map(a => ({
      filename: a.filename || null,
      media_type: a.contentType,
      decoded_sha256: crypto.createHash('sha256').update(a.content).digest('hex'),
    })),
  }));
})().catch(e => { console.error(e.message); process.exit(1); });
