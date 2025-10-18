#!/usr/bin/env node
/**
 * Tạo manifest.json từ:
 *  - data.json (để lấy title & situationCount)
 *  - build/packs/chapter*.zip (+ .sha256)
 *
 * Usage:
 *   node tools/build_manifest.js --tag v25.10.1 --repo kamedev02/ontapmophong
 */
const fs = require("fs");
const path = require("path");

function param(name, def = null) {
	const i = process.argv.indexOf(name);
	if (i === -1 || i === process.argv.length - 1) return def;
	return process.argv[i + 1];
}
function readJson(p) {
	return JSON.parse(fs.readFileSync(p, "utf8"));
}
function readSha256(p) {
	const raw = fs.readFileSync(p, "utf8").trim();
	return raw.split(/\s+/)[0];
}
function sizeOf(p) {
	return fs.statSync(p).size;
}

const TAG = param("--tag", "v25.10.1");
const REPO = param("--repo", "kamedev02/ontapmophong");
const DATA_JSON = path.join("assets", "data.json");
const PACK_DIR = path.join("build", "packs");
const OUT = path.join("build", "manifest.json");

if (!fs.existsSync(DATA_JSON)) {
	console.error("Không tìm thấy data.json ở root repo");
	process.exit(1);
}
if (!fs.existsSync(PACK_DIR)) {
	console.error(
		"Không tìm thấy build/packs. Hãy chạy tools/pack_chapters.sh trước."
	);
	process.exit(1);
}

// đọc data.json
let data = readJson(DATA_JSON);
// Chuẩn hoá: data có thể là object hoặc array
if (!Array.isArray(data)) {
	// nếu data là object có field "chapters", lấy ra
	if (Array.isArray(data.chapters)) {
		data = data.chapters;
	} else {
		console.warn(
			"Cấu trúc data.json không phải mảng chapters; sẽ fallback sang dò pack"
		);
		data = [];
	}
}

// dựng map chapter -> {title, situationCount}
const metaByFolder = {};
for (const c of data) {
	const folder = c.folder || c.id || c.name;
	if (!folder) continue;
	const title = c.title || folder;
	const situationCount = Array.isArray(c.situations)
		? c.situations.length
		: null;
	metaByFolder[folder] = { title, situationCount };
}

// duyệt các pack có thật trong build/packs
const files = fs
	.readdirSync(PACK_DIR)
	.filter((f) => /^chapter\d+\.zip$/i.test(f));
if (files.length === 0) {
	console.error("Không thấy pack chapter*.zip trong build/packs");
	process.exit(1);
}

const packs = files.map((zipName) => {
	const id = zipName.replace(/\.zip$/i, "");
	const zipPath = path.join(PACK_DIR, zipName);
	const shaPath = path.join(PACK_DIR, `${zipName}.sha256`);
	if (!fs.existsSync(shaPath)) {
		console.error(`Thiếu checksum: ${shaPath}`);
		process.exit(1);
	}
	const meta = metaByFolder[id] || {};
	return {
		id,
		title: meta.title || id,
		situationCount: meta.situationCount ?? null,
		url: `https://github.com/${REPO}/releases/download/${TAG}/${zipName}`,
		size: sizeOf(zipPath),
		sha256: readSha256(shaPath),
	};
});

const manifest = {
	version: TAG,
	updatedAt: new Date().toISOString(),
	basePath: "videos",
	dataJson: "data.json",
	packs,
};

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(manifest, null, 2));
console.log(`>> Wrote ${OUT}`);
