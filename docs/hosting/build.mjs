import { mkdir, copyFile } from 'node:fs/promises';
const output = new URL('./public/', import.meta.url);
await mkdir(output, { recursive: true });
await copyFile(new URL('../getting-started.html', import.meta.url), new URL('index.html', output));
await copyFile(new URL('./_headers', import.meta.url), new URL('_headers', output));
