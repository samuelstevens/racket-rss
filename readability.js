/* third party */
const { Readability, isProbablyReaderable } = require("@mozilla/readability");
const { JSDOM } = require("jsdom");
const createDOMPurify = require("dompurify");

/* nodejs */
const process = require("process");
const fs = require("fs");

const parse = (url, html, output) => {
  const clean = createDOMPurify(new JSDOM("").window).sanitize(html);

  const doc = new JSDOM(clean, { url });

  const reader = new Readability(doc.window.document);

  const article = reader.parse();

  if (!article) {
    output.write(
      Buffer.from(JSON.stringify({ error: `No content for ${url}` })),
    );
  }

  output.write(Buffer.from(JSON.stringify(article)));
};

const readHtml = (stream, callback) => {
  const buffer = [];
  stream.on("data", (chunk) => buffer.push(chunk));
  stream.on("end", () => callback(buffer.join("")));
};

const main = () => {
  if (process.argv.length < 3) {
    process.stdout.write(
      Buffer.from(JSON.stringify({ error: "No url argument passed" })),
    );
    process.exit(1);
  }
  const output = fs.createWriteStream("output.txt");
  readHtml(process.stdin, (html) => {
    parse(process.argv[2], html, process.stdout);
  });
};

main();
