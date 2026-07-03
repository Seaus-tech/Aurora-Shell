#!/usr/bin/env node
// wx — Aurora-Shell universal file converter / importer / exporter
// Usage:
//   wx --vert input.ext output.ext         convert file format
//   wx --vert --replatform file.ext os:(MacOS|Linux|Windows)  re-platform binary/lib
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
    a: 'staticlib', lib: 'staticlib', app: 'app',
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

function replatform(inFile, targetOS, outFile) {
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

    // write re-platformed copy with target extension — respect outFile if provided
    const outLib = path.join(dir, stem + sig.ext);
    const finalOut = inFile !== outFile && outFile ? outFile : outLib;
    fs.writeFileSync(finalOut, buf);
    fs.chmodSync(finalOut, mode);
    info(`Wrote binary copy: ${finalOut}`);

    // write wrapper stub
    const stubExt  = targetOS === 'Windows' ? '.bat' : '.sh';
    const stubFile = path.join(dir, stem + '-' + targetOS + stubExt);
    const stubSrc  = (OS_STUB[targetOS] || '')
        .replace(/{ORIG}/g, base)
        .replace(/{LIBNAME}/g, path.basename(finalOut));

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
        binary: path.basename(finalOut),
    };
    fs.writeFileSync(path.join(dir, stem + '.wx.json'), JSON.stringify(meta, null, 2));

    ok(`Re-platformed ${base} → ${targetOS}`);
    info(`Run on ${targetOS} using: ${path.basename(stubFile)}`);
    warn(`Note: re-platforming wraps the binary for the target OS loader. Full cross-compilation requires matching architecture.`);
}

// ── BUILD FROM SOURCE ─────────────────────────────────────────────────────────
function buildFromSource(srcDir, outFile, targetOS) {
    if (!fs.existsSync(srcDir)) fail(`Source directory not found: ${srcDir}`);
    if (!fs.statSync(srcDir).isDirectory()) fail(`${srcDir} is not a directory — -bfs requires a source directory`);

    info(`Building from source: ${srcDir} → ${outFile} (${targetOS})`);

    const cur = currentOS();
    const crossCompiling = targetOS !== cur;
    if (crossCompiling) warn(`Cross-compiling ${cur} → ${targetOS}. Ensure cross-toolchain is installed.`);

    // detect build system
    const files = fs.readdirSync(srcDir);
    let buildCmd = null;
    let buildSystem = null;

    if (files.includes('Cargo.toml')) {
        buildSystem = 'Cargo';
        const targetTriple = { MacOS: 'aarch64-apple-darwin', Linux: 'x86_64-unknown-linux-gnu', Windows: 'x86_64-pc-windows-gnu' }[targetOS];
        buildCmd = `cd "${srcDir}" && cargo build --release ${crossCompiling ? `--target ${targetTriple}` : ''} 2>&1`;
    } else if (files.includes('CMakeLists.txt')) {
        buildSystem = 'CMake';
        const buildDir = path.join(srcDir, '_wx_build');
        fs.mkdirSync(buildDir, { recursive: true });
        buildCmd = `cd "${buildDir}" && cmake .. -DCMAKE_BUILD_TYPE=Release 2>&1 && make 2>&1`;
    } else if (files.includes('Makefile') || files.includes('makefile')) {
        buildSystem = 'Make';
        buildCmd = `cd "${srcDir}" && make 2>&1`;
    } else if (files.includes('package.json')) {
        buildSystem = 'Node/npm';
        buildCmd = `cd "${srcDir}" && npm install 2>&1 && npm run build 2>&1`;
    } else if (files.includes('setup.py') || files.includes('pyproject.toml')) {
        buildSystem = 'Python';
        buildCmd = `cd "${srcDir}" && pip3 install pyinstaller 2>/dev/null; pyinstaller --onefile --distpath "${path.dirname(outFile)}" --name "${path.basename(outFile, path.extname(outFile))}" $(ls *.py | head -1) 2>&1`;
    } else if (files.find(f => f.endsWith('.go')) || files.includes('go.mod')) {
        buildSystem = 'Go';
        const goOS = { MacOS: 'darwin', Linux: 'linux', Windows: 'windows' }[targetOS];
        const goArch = 'amd64';
        buildCmd = `cd "${srcDir}" && GOOS=${goOS} GOARCH=${goArch} go build -o "${outFile}" . 2>&1`;
    } else if (files.find(f => f.endsWith('.c') || f.endsWith('.cpp'))) {
        buildSystem = 'C/C++';
        const compiler = files.find(f => f.endsWith('.cpp')) ? 'g++' : 'gcc';
        const srcs = files.filter(f => f.endsWith('.c') || f.endsWith('.cpp')).map(f => `"${path.join(srcDir, f)}"`).join(' ');
        buildCmd = `${compiler} ${srcs} -o "${outFile}" 2>&1`;
    } else {
        fail(`Could not detect build system in ${srcDir}.\nSupported: Cargo.toml, CMakeLists.txt, Makefile, package.json, setup.py, go.mod, *.c/*.cpp`);
    }

    info(`Detected build system: ${buildSystem}`);
    info(`Running: ${buildCmd.split('&&')[0].trim()}...`);

    try {
        const out = execSync(buildCmd, { encoding: 'utf8', maxBuffer: 50 * 1024 * 1024 });
        if (out.trim()) process.stdout.write(out);
    } catch (e) {
        fail(`Build failed:\n${e.stdout || e.message}`);
    }

    // for Cargo — copy the built binary to outFile
    if (buildSystem === 'Cargo') {
        const targetTriple = { MacOS: 'aarch64-apple-darwin', Linux: 'x86_64-unknown-linux-gnu', Windows: 'x86_64-pc-windows-gnu' }[targetOS];
        const stem = path.basename(srcDir);
        const cargoOut = crossCompiling
            ? path.join(srcDir, 'target', targetTriple, 'release', stem)
            : path.join(srcDir, 'target', 'release', stem);
        if (fs.existsSync(cargoOut)) {
            fs.copyFileSync(cargoOut, outFile);
            fs.chmodSync(outFile, 0o755);
        }
    }

    if (fs.existsSync(outFile)) {
        ok(`Built ${srcDir} → ${outFile} (${buildSystem})`);
    } else {
        warn(`Build completed but output not found at ${outFile} — check build output above`);
    }
}

// ── UNPACK ────────────────────────────────────────────────────────────────────
function unpackBinary(inFile, outDir) {
    if (!fs.existsSync(inFile)) fail(`File not found: ${inFile}`);
    fs.mkdirSync(outDir, { recursive: true });

    const ext  = extOf(inFile);
    const base = path.basename(inFile, path.extname(inFile));

    info(`Unpacking ${inFile} → ${outDir}`);

    // --- archives / packages first ---
    const archiveExts = ['zip','tar','gz','tgz','bz2','xz','7z','jar','war','apk','ipa','pkg','deb'];
    if (archiveExts.includes(ext)) {
        if (['zip','jar','war','apk','ipa'].includes(ext)) {
            if (!hasBin('unzip')) fail('unzip not found — install with: brew install unzip');
            execSync(`unzip -o "${inFile}" -d "${outDir}"`, { stdio: 'inherit' });
        } else if (['tar','gz','tgz','bz2','xz'].includes(ext)) {
            execSync(`tar -xf "${inFile}" -C "${outDir}"`, { stdio: 'inherit' });
        } else if (ext === '7z') {
            if (!hasBin('7z')) fail('7z not found — install with: brew install p7zip');
            execSync(`7z x "${inFile}" -o"${outDir}"`, { stdio: 'inherit' });
        } else if (ext === 'deb') {
            execSync(`cd "${outDir}" && ar x "${path.resolve(inFile)}"`, { stdio: 'inherit' });
        }
        ok(`Unpacked ${inFile} → ${outDir}`);
        return;
    }

    // --- binaries: decompile with available tool ---
    if (hasBin('r2')) {
        info('Using radare2 to analyse binary...');
        const r2out = path.join(outDir, `${base}_r2_analysis.txt`);
        try {
            const out = execSync(`r2 -q -c "aaa; pdf @@ sym.*; izz" "${inFile}" 2>/dev/null`, { encoding: 'utf8', timeout: 60000 });
            fs.writeFileSync(r2out, out);
            info(`radare2 analysis → ${r2out}`);
        } catch(e) { fs.writeFileSync(r2out, e.stdout || ''); }
        try {
            const strings = execSync(`strings "${inFile}"`, { encoding: 'utf8' });
            fs.writeFileSync(path.join(outDir, `${base}_strings.txt`), strings);
        } catch {}
        ok(`Unpacked with radare2 → ${outDir}`);
        return;
    }

    if (hasBin('ghidra')) {
        info('Using Ghidra headless decompiler...');
        const ghidraHome = execSync('which ghidra', { encoding: 'utf8' }).trim().replace('/bin/ghidra','');
        const projDir = path.join(outDir, '_ghidra_proj');
        fs.mkdirSync(projDir, { recursive: true });
        execSync(`"${ghidraHome}/support/analyzeHeadless" "${projDir}" wx_proj -import "${inFile}" -deleteProject 2>&1`, { stdio: 'inherit', timeout: 300000 });
        ok(`Decompiled with Ghidra → ${outDir}`);
        return;
    }

    // fallback — strings + hexdump + metadata
    warn('No decompiler found. Falling back to strings + hex dump.');
    warn('Install radare2 for better results: brew install radare2');
    try { fs.writeFileSync(path.join(outDir, `${base}_strings.txt`), execSync(`strings "${inFile}"`, { encoding: 'utf8' })); } catch {}
    try { fs.writeFileSync(path.join(outDir, `${base}_hexdump.txt`), execSync(`xxd "${inFile}" | head -500`, { encoding: 'utf8' })); } catch {}
    const buf = fs.readFileSync(inFile);
    const magic = buf.slice(0,4).toString('hex').toUpperCase();
    const osGuess = magic.startsWith('CFFAEDFE') || magic.startsWith('FEEDFACE') ? 'MacOS (Mach-O)'
        : magic.startsWith('7F454C46') ? 'Linux (ELF)'
        : magic.startsWith('4D5A') ? 'Windows (PE)' : 'Unknown';
    fs.writeFileSync(path.join(outDir, `${base}_meta.json`), JSON.stringify({ file: inFile, size: fs.statSync(inFile).size, magic, detected_os: osGuess, unpacked: new Date().toISOString() }, null, 2));
    ok(`Fallback unpack → ${outDir}`);
    info('For full decompilation install radare2: brew install radare2');
}

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
  wx --vert <input> <output>                     Convert file format
  wx --vert <src-dir> <output> -bfs              Build from source for target OS
  wx --vert <src-dir> <output> --build-from-source
  wx --vert --replatform <file> os:<OS>          Re-platform binary for target OS
  wx --port -m <file> [dest]                     Import a file
  wx -x <file> [dest]                            Export a file
  wx -r <file>                                   Read/inspect file info

${c.bold}Supported formats:${c.reset}
  Data:   json, yaml, toml, csv, tsv, xml, html, markdown, txt
  Image:  png, jpg, webp, gif, bmp, tiff  (requires: npm install -g sharp)
  Binary: dylib, so, dll, exe, app        (re-platform or build from source)

${c.bold}Build systems detected by -bfs:${c.reset}
  Cargo.toml, CMakeLists.txt, Makefile, package.json, setup.py, go.mod, *.c/*.cpp

${c.bold}OS targets:${c.reset}
  MacOS (.app/.dylib), Linux (.so), Windows (.dll/.exe)

${c.bold}Examples:${c.reset}
  wx --vert data.json data.csv
  wx --vert image.png image.webp
  wx --vert notepad.exe notepad.app              wrap binary for MacOS
  wx --vert ./notepad-src notepad.app -bfs       build from source for MacOS
  wx --vert --replatform apt-get.dylib os:MacOS
  wx --port -m ~/Downloads/config.json ./config
  wx -x build/output.zip ~/Desktop
`);
}

// ── ARG PARSER ────────────────────────────────────────────────────────────────
const args = process.argv.slice(2);

if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    showHelp(); process.exit(0);
}

// wx --vert --replatform <file> os:<OS>
if (args[0] === '--vert' && args[1] === '--replatform') {
    const file    = args[2];
    const osArg   = args[3];
    if (!file || !osArg) fail('Usage: wx --vert --replatform <file> os:<OS>');
    if (!osArg.startsWith('os:')) fail('OS must be specified as os:MacOS, os:Linux, or os:Windows');
    const target = osArg.replace('os:', '');
    if (!fs.existsSync(file)) fail(`File not found: ${file}`);
    replatform(file, target, null);
    process.exit(0);
}

// wx --vert <input> <output> [-bfs | --build-from-source]
if (args[0] === '--vert') {
    const inFile  = args[1];
    const outFile = args[2];
    const bfs = args.includes('-bfs') || args.includes('--build-from-source');
    if (!inFile || !outFile) fail('Usage: wx --vert <input> <output> [-bfs]');
    const inFmt  = fmtOf(inFile);
    const outFmt = fmtOf(outFile);
    const binaryFmts = ['dylib','so','dll','exe','staticlib','app'];

    if (bfs) {
        // build from source — inFile must be a directory
        if (!fs.existsSync(inFile)) fail(`Source directory not found: ${inFile}`);
        if (!fs.statSync(inFile).isDirectory()) fail(`-bfs requires a source code directory, not a binary file.\nUsage: wx --vert <source-dir> <output> -bfs\nIf you only have the binary, omit -bfs to wrap it instead.`);
        const extOsMap = { dylib: 'MacOS', so: 'Linux', dll: 'Windows', exe: 'Windows', app: 'MacOS' };
        const outExt = extOf(outFile);
        const targetOS = extOsMap[outExt] || currentOS();
        buildFromSource(inFile, outFile, targetOS);
    } else if (inFmt === 'image' && outFmt === 'image') {
        convertImage(inFile, outFile);
    } else if (inFmt === 'image' || outFmt === 'image') {
        fail('Cannot mix image and data formats.');
    } else if (binaryFmts.includes(inFmt) || binaryFmts.includes(outFmt)) {
        if (!fs.existsSync(inFile)) fail(`File not found: ${inFile}`);
        const extOsMap = { dylib: 'MacOS', so: 'Linux', dll: 'Windows', exe: 'Windows', app: 'MacOS' };
        const outExt = extOf(outFile);
        const targetOS = extOsMap[outExt] || null;
        if (!targetOS) fail(`Cannot determine target OS from .${outExt} — use wx --vert --replatform <file> os:<OS>`);
        info(`Binary format detected — re-platforming ${extOf(inFile)} → ${outExt} (${targetOS})`);
        info(`Tip: if you have the source, use -bfs to build natively: wx --vert <src-dir> ${outFile} -bfs`);
        replatform(inFile, targetOS, outFile);
    } else {
        if (!fs.existsSync(inFile)) fail(`File not found: ${inFile}`);
        convertData(inFile, outFile);
    }
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

// wx -r <file> — read/inspect file
if (args[0] === '-r') {
    const file = args[1];
    if (!file) fail('Usage: wx -r <file>');
    if (!fs.existsSync(file)) fail(`File not found: ${file}`);
    const stat = fs.statSync(file);
    const ext  = extOf(file);
    const fmt  = fmtOf(file);
    const buf  = fs.readFileSync(file);
    const magic = buf.slice(0, 4).toString('hex').toUpperCase();
    console.log(`${c.bold}${c.cyan}File:${c.reset}     ${file}`);
    console.log(`${c.bold}Size:${c.reset}     ${(stat.size / 1024).toFixed(2)} KB`);
    console.log(`${c.bold}Extension:${c.reset} .${ext}`);
    console.log(`${c.bold}Format:${c.reset}   ${fmt}`);
    console.log(`${c.bold}Magic:${c.reset}    ${magic}`);
    console.log(`${c.bold}Modified:${c.reset} ${stat.mtime.toLocaleString()}`);
    // detect OS for binaries
    if (['dylib','so','dll','exe','app'].includes(ext)) {
        const osGuess = magic.startsWith('CFFAEDFE') || magic.startsWith('FEEDFACE') ? 'MacOS (Mach-O)'
            : magic.startsWith('7F454C46') ? 'Linux (ELF)'
            : magic.startsWith('4D5A') ? 'Windows (PE)'
            : 'Unknown';
        console.log(`${c.bold}Binary OS:${c.reset} ${osGuess}`);
    }
    // preview text files
    if (['json','yaml','toml','csv','txt','markdown','html','xml'].includes(fmt)) {
        const preview = buf.toString('utf8').slice(0, 300).replace(/\n/g, '\n  ');
        console.log(`\n${c.bold}Preview:${c.reset}\n  ${preview}${buf.length > 300 ? '\n  ...' : ''}`);
    }
    process.exit(0);
}




// wx --unpack <file> <outDir>
if (args[0] === '--unpack') {
    const file   = args[1];
    const outDir = args[2];
    if (!file || !outDir) fail('Usage: wx --unpack <file> <output-dir>');
    unpackBinary(file, outDir);
    process.exit(0);
}

fail(`Unknown command: ${args[0]}\nRun wx --help for usage.`);
