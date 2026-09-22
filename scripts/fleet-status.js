#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const glob = require('child_process').execSync;

const repoRoot = path.resolve(__dirname, '..');
const deploymentsDir = path.join(repoRoot, 'terragrunt/deployments');
const manifestFile = path.join(repoRoot, '.release-please-manifest.json');

const latestVersions = JSON.parse(fs.readFileSync(manifestFile, 'utf8'));

console.log('='.repeat(95));
console.log('           FLEET STATUS: TERRAFORM MODULE ROLLOUT & DRIFT MATRIX           ');
console.log('='.repeat(95));
console.log(
  'ENVIRONMENT'.padEnd(14) +
  'CLUSTER / PATH'.padEnd(35) +
  'MODULE'.padEnd(20) +
  'CURRENT'.padEnd(12) +
  'LATEST'.padEnd(10) +
  'STATUS'
);
console.log('-'.repeat(95));

function walk(dir) {
  let results = [];
  const list = fs.readdirSync(dir);
  list.forEach(file => {
    file = path.join(dir, file);
    const stat = fs.statSync(file);
    if (stat && stat.isDirectory()) {
      if (!file.includes('.terragrunt-cache')) {
        results = results.concat(walk(file));
      }
    } else if (file.endsWith('terragrunt.hcl')) {
      results.push(file);
    }
  });
  return results;
}

const files = walk(deploymentsDir);

files.forEach(file => {
  const rel = path.relative(deploymentsDir, file);
  const parts = rel.split(path.sep);
  const env = parts[0];
  const cluster = parts.slice(1, -1).join('/');

  const content = fs.readFileSync(file, 'utf8');
  const match = content.match(/source\s*=\s*"git::.*?\/([a-zA-Z0-9_\/-]+)\?ref=modules\/([a-zA-Z0-9_-]+)-v([0-9.]+)"/);

  if (match) {
    const modPath = match[1];
    const modPkg = match[2];
    const currentVer = match[3];

    // Find latest version from manifest
    let latestVer = 'unknown';
    for (const [pkgPath, ver] of Object.entries(latestVersions)) {
      if (pkgPath.endsWith(modPkg.replace('-', '_')) || pkgPath.endsWith(modPkg)) {
        latestVer = ver;
        break;
      }
    }

    const isLatest = currentVer === latestVer;
    const status = isLatest ? '✅ UP-TO-DATE' : '⏳ OUTDATED (Canary/Pending)';

    console.log(
      env.padEnd(14) +
      cluster.padEnd(35) +
      modPkg.padEnd(20) +
      ('v' + currentVer).padEnd(12) +
      ('v' + latestVer).padEnd(10) +
      status
    );
  }
});

console.log('='.repeat(95));
