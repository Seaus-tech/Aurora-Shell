#!/usr/bin/env node
// wx — Aurora-Shell universal file converter / importer / exporter
// Usage:
//   wx --vert input.ext output.ext         convert file format
//   wx --vert -r file.ext os:(MacOS|Linux|Windows)  re-platform binary/lib
//   wx --port -m file [dest]               import file
//   wx -x file [dest]                      export file

'use strict';

const fs   = require('fs');
const path = require('path');
const os   = require('os');
const { execSync, spawnSync } = require('child_process');

// ── colour helpers ────────────────────────────────────────────────────────────
const c = {
    reset:  '\x1b[0m',
    green:  '\x1b[32m',
    red:    '\x1b[31m',
    yellow: '\x1b[33m',
    cyan:   '\x1b[36m',
    bold:   '\x1b[1m',
};
const ok   = (m) => console.log(`${c.green}✅ ${m}${c.reset}`);
const fail = (m) => { console.error(`${c.red}❌ ${m}${c.reset}`); process.exit(1); };
const info = (m) => console.log(`${c.cyan}ℹ  ${m}${c.reset}`);
const warn = (m) => console.log(`${c.yellow}⚠  ${m}${c.reset}`);

// ── current OS detection ──────────────────────────────────────────────────────
function currentOS() {
    switch (process.platform) {
        case 'darwin': return 'MacOS';
        case 'linux':  return 'Linux';
        case 'win32':  return 'Windows';
        default:       return process.platform;
    }
}

// ── extension → format map ────────────────────────────────────────────────────
const FORMAT = {
    // text / data
    json: 'json', yaml: 'yaml', yml: 'yaml', toml: 'toml',
    csv: 'csv', tsv: 'tsv', xml: 'xml', html: 'html', htm: 'html',
    md: 'markdown', markdown: 'markdown', txt: 'text',
    // binary / lib
    dylib: 'dylib', so: 'so', dll: 'dll', exe: 'exe',
    a: 'staticlib', lib: 'staticlib',
    // images (requires sharp if installed)
    png: 'image', jpg: 'image', jpeg: 'image', gif: 'image',
    webp: 'image', bmp: 'image', tiff: 'image', tif: 'image',
};

function extOf(f) { return path.extname(f).replace('.', '').toLowerCase(); }
function fmtOf(f) { return FORMAT[extOf(f)] || extOf(f); }

// ── dependency check helpers ──────────────────────────────────────────────────
function hasBin(b) {
    try { execSync(`command -v ${b}`, { stdio: 'ignore' }); return true; }
    catch { return false; }
}
function requireNpm(pkg) {
    try { require(pkg); } catch {
        info(`Installing required package: ${pkg}`);
        execSync(`npm install -g ${pkg}`, { stdio: 'inherit' });
    }
}

// ── DATA CONVERTERS ───────────────────────────────────────────────────────────
function convertData(inFile, outFile) {
    const inFmt  = fmtOf(inFile);
    const outFmt = fmtOf(outFile);
    if (inFmt === outFmt) { fail(`Input and output formats are the same (${inFmt})`); }

    info(`Converting ${inFmt} → ${outFmt}`);
    const raw = fs.readFileSync(inFile, 'utf8');
    let data;

    // --- PARSE INPUT ---
    switch (inFmt) {
        case 'json':
            data = JSON.parse(raw);
            break;
        case 'yaml': {
            requireNpm('js-yaml');
            const yaml = require('js-yaml');
            data = yaml.load(raw);
            break;
        }
        case 'toml': {
            requireNpm('@iarna/toml');
            const toml = require('@iarna/toml');
            data = toml.parse(raw);
            break;
        }
        case 'csv':
        case 'tsv': {
            const sep = inFmt === 'tsv' ? '\t' : ',';
            const lines = raw.trim().split('\n');
            const headers = lines[0].split(sep).map(h => h.trim().replace(/^"|"$/g, ''));
            data = lines.slice(1).map(line => {
                const vals = line.split(sep).map(v => v.trim().replace(/^"|"$/g, ''));
                return Object.fromEntries(headers.map((h, i) => [h, vals[i] ?? '']));
            });
            break;
        }
        case 'xml': {
            requireNpm('xml2js');
            const { parseStringSync } = require('xml2js');
            // xml2js parseString is async — use execSync trick via temp
            const xml2js = require('xml2js');
            let parsed;
            xml2js.parseString(raw, { explicitArray: false }, (e, r) => { if (e) fail(e.message); parsed = r; });
            data = parsed;
            break;
        }
        case 'text':
        case 'markdown':
            data = raw;
            break;
        default:
            fail(`Cannot parse input format: ${inFmt}`);
    }

    // --- SERIALIZE OUTPUT ---
    let out;
    switch (outFmt) {
        case 'json':
            out = JSON.stringify(data, null, 2);
            break;
        case 'yaml': {
            requireNpm('js-yaml');
            const yaml = require('js-yaml');
            out = yaml.dump(data);
            break;
        }
        case 'toml': {
            requireNpm('@iarna/toml');
            const toml = require('@iarna/toml');
            out = toml.stringify(typeof data === 'object' ? data : { value: data });
            break;
        }
        case 'csv':
        case 'tsv': {
            const sep = outFmt === 'tsv' ? '\t' : ',';
            const rows = Array.isArray(data) ? data : [data];
            const headers = Object.keys(rows[0] || {});
            out = [headers.join(sep), ...rows.map(r => headers.map(h => `"${r[h] ?? ''}"`).join(sep))].join('\n');
            break;
        }
        case 'xml': {
            requireNpm('xml2js');
            const xml2js = require('xml2js');
            const builder = new xml2js.Builder();
            out = builder.buildObject(typeof data === 'object' ? data : { root: data });
            break;
        }
        case 'markdown':
        case 'text':
        case 'html':
            out = typeof data === 'string' ? data : JSON.stringify(data, null, 2);
            break;
        default:
            fail(`Cannot serialize to output format: ${outFmt}`);
    }

    fs.writeFileSync(outFile, out, 'utf8');
    ok(`Converted ${inFile} → ${outFile}`);
}

// ── IMAGE CONVERTER ───────────────────────────────────────────────────────────
function convertImage(inFile, outFile) {
    requireNpm('sharp');
    const sharp = require('sharp');
    info(`Converting image ${extOf(inFile)} → ${extOf(outFile)}`);
    sharp(inFile).toFile(outFile, (err) => {
        if (err) fail(err.message);
        ok(`Converted ${inFile} → ${outFile}`);
    });
}

// ── RE-PLATFORM ENGINE ────────────────────────────────────────────────────────
const OS_SIGS = {
    MacOS:   { magic: Buffer.from([0xCF, 0xFA, 0xED, 0xFE]), ext: '.dylib', note: 'Mach-O 64-bit' },
    Linux:   { magic: Buffer.from([0x7F, 0x45, 0x4C, 0x46]), ext: '.so',    note: 'ELF' },
    Windows: { magic: Buffer.from([0x4D, 0x5A]),               ext: '.dll',  note: 'PE/MZ' },
};

const OS_STUB = {
    MacOS: `#!/bin/bash
# wx re-platform stub — MacOS wrapper
# Original: {ORIG}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="$SCRIPT_DIR/{LIBNAME}"
if [[ "$(uname)" != "Darwin" ]]; then
  echo "❌ This binary was re-platformed for MacOS only." >&2; exit 1
fi
export DYLD_LIBRARY_PATH="$SCRIPT_DIR:$DYLD_LIBRARY_PATH"
exec "$LIB" "$@"`,

    Linux: `#!/bin/bash
# wx re-platform stub — Linux wrapper
# Original: {ORIG}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="$SCRIPT_DIR/{LIBNAME}"
if [[ "$(uname)" != "Linux" ]]; then
  echo "❌ This binary was re-platformed for Linux only." >&2; exit 1
fi
export LD_LIBRARY_PATH="$SCRIPT_DIR:$LD_LIBRARY_PATH"
exec "$LIB" "$@"`,

    Windows: `@echo off
rem wx re-platform stub — Windows wrapper
rem Original: {ORIG}
set SCRIPT_DIR=%~dp0
set LIB=%SCRIPT_DIR%{LIBNAME}
if not "%OS%"=="Windows_NT" (
  echo This binary was re-platformed for Windows only. && exit /b 1
)
"%LIB%" %*`,
};

function replatform(inFile, targetOS) {
    if (!OS_SIGS[targetOS]) fail(`Unknown OS target: ${targetOS}. Use MacOS, Linux, or Windows.`);

    info(`Re-platforming ${inFile} for ${targetOS}`);
    // copy execute permissions from original, always ensure +x
    let mode = 0o755;
    try { mode = fs.statSync(inFile).mode | 0o111; } catch {}
    const buf  = fs.readFileSync(inFile);
    const sig  = OS_SIGS[targetOS];
    const cur  = currentOS();
    const base = path.basename(inFile);
    const dir  = path.dirname(inFile);
    const stem = path.basename(inFile, path.extname(inFile));

    // write re-platformed copy with target extension
    const outLib = path.join(dir, stem + sig.ext);
    fs.writeFileSync(outLib, buf);
    fs.chmodSync(outLib, mode);
    info(`Wrote binary copy: ${outLib}`);

    // write wrapper stub
    const stubExt  = targetOS === 'Windows' ? '.bat' : '.sh';
    const stubFile = path.join(dir, stem + '-' + targetOS + stubExt);
    const stubSrc  = (OS_STUB[targetOS] || '')
        .replace(/{ORIG}/g, base)
        .replace(/{LIBNAME}/g, path.basename(outLib));

    fs.writeFileSync(stubFile, stubSrc, 'utf8');
    if (targetOS !== 'Windows') fs.chmodSync(stubFile, 0o755);

    // write metadata sidecar
    const meta = {
        wx_replatform: true,
        original: base,
        original_os: cur,
        target_os: targetOS,
        format: sig.note,
        date: new Date().toISOString(),
        stub: path.basename(stubFile),
        binary: path.basename(outLib),
    };
    fs.writeFileSync(path.join(dir, stem + '.wx.json'), JSON.stringify(meta, null, 2));

    ok(`Re-platformed ${base} → ${targetOS}`);
    info(`Run on ${targetOS} using: ${path.basename(stubFile)}`);
    warn(`Note: re-platforming wraps the binary for the target OS loader. Full cross-compilation requires matching architecture.`);
}

// ── IMPORT ────────────────────────────────────────────────────────────────────
function importFile(src, dest) {
    if (!fs.existsSync(src)) fail(`Source not found: ${src}`);
    const dst = dest
        ? path.join(dest, path.basename(src))
        : path.join(process.cwd(), path.basename(src));
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.copyFileSync(src, dst);
    ok(`Imported ${src} → ${dst}`);
}

// ── EXPORT ────────────────────────────────────────────────────────────────────
function exportFile(src, dest) {
    if (!fs.existsSync(src)) fail(`Source not found: ${src}`);
    const dst = dest
        ? path.join(dest, path.basename(src))
        : path.join(os.homedir(), 'Desktop', path.basename(src));
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.copyFileSync(src, dst);
    ok(`Exported ${src} → ${dst}`);
}

// ── HELP ──────────────────────────────────────────────────────────────────────
function showHelp() {
    console.log(`
${c.bold}${c.cyan}wx${c.reset} — Aurora-Shell universal file tool

${c.bold}Usage:${c.reset}
  wx --vert <input> <output>                  Convert file format
  wx --vert -r <file> os:<OS>                 Re-platform binary for target OS
  wx --port -m <file> [dest]                  Import a file
  wx -x <file> [dest]                         Export a file

${c.bold}Supported formats:${c.reset}
  Data:   json, yaml, toml, csv, tsv, xml, html, markdown, txt
  Image:  png, jpg, webp, gif, bmp, tiff  (requires: npm install -g sharp)
  Binary: dylib, so, dll, exe, lib        (re-platform only)

${c.bold}OS targets for --vert -r:${c.reset}
  MacOS, Linux, Windows

${c.bold}Examples:${c.reset}
  wx --vert data.json data.csv
  wx --vert data.yaml data.toml
  wx --vert image.png image.webp
  wx --vert -r apt-get.dylib os:MacOS
  wx --port -m ~/Downloads/config.json ./config
  wx -x build/output.zip ~/Desktop
`);
}

// ── ARG PARSER ────────────────────────────────────────────────────────────────
const args = process.argv.slice(2);

if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    showHelp(); process.exit(0);
}

// wx --vert -r <file> os:<OS>
if (args[0] === '--vert' && args[1] === '-r') {
    const file    = args[2];
    const osArg   = args[3];
    if (!file || !osArg) fail('Usage: wx --vert -r <file> os:<OS>');
    if (!osArg.startsWith('os:')) fail('OS must be specified as os:MacOS, os:Linux, or os:Windows');
    const target = osArg.replace('os:', '');
    if (!fs.existsSync(file)) fail(`File not found: ${file}`);
    replatform(file, target);
    process.exit(0);
}

// wx --vert <input> <output>
if (args[0] === '--vert') {
    const inFile  = args[1];
    const outFile = args[2];
    if (!inFile || !outFile) fail('Usage: wx --vert <input> <output>');
    if (!fs.existsSync(inFile)) fail(`File not found: ${inFile}`);
    const inFmt  = fmtOf(inFile);
    const outFmt = fmtOf(outFile);
    if (inFmt === 'image' && outFmt === 'image') { convertImage(inFile, outFile); }
    else if (inFmt === 'image' || outFmt === 'image') { fail('Cannot mix image and data formats. Use image→image or data→data.'); }
    else { convertData(inFile, outFile); }
    process.exit(0);
}

// wx --port -m <file> [dest]
if (args[0] === '--port' && args[1] === '-m') {
    const file = args[2];
    const dest = args[3] || null;
    if (!file) fail('Usage: wx --port -m <file> [dest]');
    importFile(file, dest);
    process.exit(0);
}

// wx -x <file> [dest]
if (args[0] === '-x') {
    const file = args[1];
    const dest = args[2] || null;
    if (!file) fail('Usage: wx -x <file> [dest]');
    exportFile(file, dest);
    process.exit(0);
}

fail(`Unknown command: ${args[0]}\nRun wx --help for usage.`);
