#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG_PATH="$REPO_ROOT/skills.json"
EXTERNAL_DIR="$REPO_ROOT/.external"

if [[ ! -f "$CONFIG_PATH" ]]; then
  printf 'Missing %s\n' "$CONFIG_PATH" >&2
  exit 1
fi

mkdir -p "$EXTERNAL_DIR"

node - "$REPO_ROOT" "$CONFIG_PATH" "$EXTERNAL_DIR" <<'NODE'
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const [repoRoot, configPath, externalDir] = process.argv.slice(2);
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const managedMarker = '.skills-install.json';

function expandHome(input) {
  const expanded = input.startsWith('~/') ? path.join(os.homedir(), input.slice(2)) : input;
  return path.resolve(expanded);
}

function git(args, cwd) {
  return execFileSync('git', args, {
    cwd,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'inherit']
  }).trim();
}

function repoSlug(repoUrl) {
  return repoUrl
    .replace(/^https?:\/\/github\.com\//, '')
    .replace(/\.git$/, '')
    .replace(/[^a-zA-Z0-9._-]+/g, '__');
}

function ensureRepo(repoUrl) {
  const slug = repoSlug(repoUrl);
  const repoPath = path.join(externalDir, slug);

  if (!fs.existsSync(repoPath)) {
    execFileSync('git', ['clone', repoUrl, repoPath], { stdio: 'inherit' });
  } else {
    git(['pull', '--ff-only'], repoPath);
  }

  return path.resolve(repoPath);
}

function pruneExternalRepos(repoConfigs) {
  if (!fs.existsSync(externalDir)) return;

  const expectedRepoSlugs = new Set((repoConfigs || []).map((repoConfig) => repoSlug(repoConfig.repo)));

  for (const entry of fs.readdirSync(externalDir, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    if (expectedRepoSlugs.has(entry.name)) continue;
    fs.rmSync(path.join(externalDir, entry.name), { recursive: true, force: true });
  }
}

function getExternalRepoRoot(sourcePath) {
  const absoluteSourcePath = path.resolve(sourcePath);
  const absoluteExternalDir = path.resolve(externalDir);

  if (!absoluteSourcePath.startsWith(absoluteExternalDir + path.sep)) {
    return '';
  }

  const relativeToExternal = path.relative(absoluteExternalDir, absoluteSourcePath);
  const [repoSlug] = relativeToExternal.split(path.sep);
  return repoSlug ? path.join(absoluteExternalDir, repoSlug) : '';
}

function isManagedSymlink(targetPath) {
  const stats = fs.lstatSync(targetPath, { throwIfNoEntry: false });
  if (!stats || !stats.isSymbolicLink()) return false;

  const resolved = fs.realpathSync(targetPath);
  return resolved === repoRoot || resolved.startsWith(repoRoot + path.sep);
}

function isManagedCopy(targetPath) {
  const stats = fs.lstatSync(targetPath, { throwIfNoEntry: false });
  if (!stats || !stats.isDirectory() || stats.isSymbolicLink()) return false;
  return fs.existsSync(path.join(targetPath, managedMarker));
}

function parseSkillName(skillFile) {
  const content = fs.readFileSync(skillFile, 'utf8');
  const frontmatter = content.match(/^---\n([\s\S]*?)\n---/);
  if (!frontmatter) {
    throw new Error(`Missing frontmatter in ${skillFile}`);
  }
  const nameMatch = frontmatter[1].match(/^name:\s*(.+)$/m);
  if (!nameMatch) {
    throw new Error(`Missing name in ${skillFile}`);
  }
  return nameMatch[1].trim().replace(/^['"]|['"]$/g, '');
}

function parseFrontmatter(skillFile) {
  const content = fs.readFileSync(skillFile, 'utf8');
  const frontmatter = content.match(/^---\n([\s\S]*?)\n---/);
  if (!frontmatter) {
    throw new Error(`Missing frontmatter in ${skillFile}`);
  }

  const data = {};
  for (const line of frontmatter[1].split('\n')) {
    const match = line.match(/^([a-zA-Z0-9_-]+):\s*(.+)$/);
    if (!match) continue;
    data[match[1]] = match[2].trim().replace(/^['"]|['"]$/g, '');
  }
  return data;
}

function removeTarget(targetPath) {
  const existing = fs.lstatSync(targetPath, { throwIfNoEntry: false });
  if (!existing) return;
  if (existing.isSymbolicLink()) {
    fs.unlinkSync(targetPath);
    return;
  }
  if (existing.isDirectory()) {
    fs.rmSync(targetPath, { recursive: true, force: true });
    return;
  }
  throw new Error(`Refusing to replace unsupported target ${targetPath}`);
}

function buildInstallContext(sourcePath, targetPath, targetBase) {
  const absoluteRepoRoot = path.resolve(repoRoot);
  const absoluteSourcePath = path.resolve(sourcePath);
  const absoluteTargetPath = path.resolve(targetPath);
  const absoluteTargetBase = path.resolve(targetBase);

  return {
    __SKILLS_REPO_ROOT__: absoluteRepoRoot,
    __AGENTS_SKILLS_DIR__: expandHome('~/.agents/skills'),
    __CLAUDE_SKILLS_DIR__: expandHome('~/.claude/skills'),
    __EXTERNAL_REPO_ROOT__: getExternalRepoRoot(absoluteSourcePath),
    __SOURCE_SKILL_DIR__: absoluteSourcePath,
    __INSTALLED_SKILL_DIR__: absoluteTargetPath,
    __INSTALL_TARGET_DIR__: absoluteTargetBase
  };
}

function replacePlaceholders(content, context) {
  let result = content.toString('utf8');
  for (const [key, value] of Object.entries(context)) {
    result = result.split(key).join(value);
  }
  return result;
}

function copyDirWithSubstitution(sourceDir, targetDir, context) {
  fs.mkdirSync(targetDir, { recursive: true });
  for (const entry of fs.readdirSync(sourceDir, { withFileTypes: true })) {
    if (entry.name === '.git' || entry.name === 'node_modules') continue;
    const sourcePath = path.join(sourceDir, entry.name);
    const targetPath = path.join(targetDir, entry.name);
    if (entry.isDirectory()) {
      copyDirWithSubstitution(sourcePath, targetPath, context);
      continue;
    }
    if (!entry.isFile()) continue;
    const content = fs.readFileSync(sourcePath);
    const originalText = content.toString('utf8');
    const replacedText = replacePlaceholders(content, context);
    if (replacedText !== originalText) {
      fs.writeFileSync(targetPath, replacedText);
      continue;
    }
    fs.copyFileSync(sourcePath, targetPath);
  }
}

function installMaterializedCopy(targetPath, sourcePath, targetBase) {
  const existing = fs.lstatSync(targetPath, { throwIfNoEntry: false });
  if (existing) {
    if (existing.isSymbolicLink()) {
      fs.unlinkSync(targetPath);
    } else if (isManagedCopy(targetPath)) {
      fs.rmSync(targetPath, { recursive: true, force: true });
    } else {
      throw new Error(`Refusing to replace non-managed directory ${targetPath}`);
    }
  }

  const installContext = buildInstallContext(sourcePath, targetPath, targetBase);
  copyDirWithSubstitution(sourcePath, targetPath, installContext);
  fs.writeFileSync(path.join(targetPath, managedMarker), JSON.stringify({ mode: 'copy', source: sourcePath }, null, 2) + '\n');
}

function collectSkillDirs(baseDir) {
  const results = [];

  function walk(currentDir) {
    const entries = fs.readdirSync(currentDir, { withFileTypes: true });
    const hasSkill = entries.some((entry) => entry.isFile() && entry.name === 'SKILL.md');
    if (hasSkill) {
      results.push(currentDir);
      return;
    }

    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      if (entry.name === '.git' || entry.name === 'node_modules') continue;
      walk(path.join(currentDir, entry.name));
    }
  }

  walk(baseDir);
  return results;
}

function collectLocalSkillDirs() {
  return fs.readdirSync(repoRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .filter((entry) => !entry.name.startsWith('.'))
    .map((entry) => path.join(repoRoot, entry.name))
    .filter((dir) => fs.existsSync(path.join(dir, 'SKILL.md')));
}

function resolveRepoSkillDirs(repoConfig) {
  const repoPath = ensureRepo(repoConfig.repo);
  if (Array.isArray(repoConfig.only) && repoConfig.only.length > 0) {
    return repoConfig.only.map((skillPath) => {
      const resolved = skillPath === '.' ? repoPath : path.join(repoPath, skillPath);
      const skillFile = path.join(resolved, 'SKILL.md');
      if (!fs.existsSync(skillFile)) {
        throw new Error(`Missing SKILL.md at ${resolved}`);
      }
      return resolved;
    });
  }
  return collectSkillDirs(repoPath);
}

function ensureSymlink(targetPath, sourcePath) {
  const targetDir = path.dirname(targetPath);
  fs.mkdirSync(targetDir, { recursive: true });

  const existing = fs.lstatSync(targetPath, { throwIfNoEntry: false });
  if (existing) {
    if (existing.isSymbolicLink()) {
      const current = fs.realpathSync(targetPath);
      const desired = fs.realpathSync(sourcePath);
      if (current === desired) return;
      fs.unlinkSync(targetPath);
    } else {
      throw new Error(`Refusing to replace non-symlink ${targetPath}`);
    }
  }

  fs.symlinkSync(sourcePath, targetPath, 'dir');
}

function installTarget(targetPath, sourcePath, targetBase) {
  const skillFile = path.join(sourcePath, 'SKILL.md');
  const frontmatter = parseFrontmatter(skillFile);
  if (frontmatter.install_mode === 'materialize') {
    installMaterializedCopy(targetPath, sourcePath, targetBase);
    return;
  }

  if (isManagedCopy(targetPath)) {
    fs.rmSync(targetPath, { recursive: true, force: true });
  }
  ensureSymlink(targetPath, sourcePath);
}

const targets = (config.install_targets || []).map(expandHome);
const skillOverrides = config.skill_overrides || {};
const installed = [];
const definedNames = new Set();
const seenByTarget = new Map();
for (const targetBase of targets) seenByTarget.set(targetBase, new Set());

function resolveTargetsForSkill(skillName) {
  const override = skillOverrides[skillName];
  if (!override || !Array.isArray(override.targets) || override.targets.length === 0) {
    return targets;
  }
  const allowed = new Set(override.targets.map(expandHome));
  const filtered = targets.filter((t) => allowed.has(t));
  if (filtered.length === 0) {
    throw new Error(`skill_overrides for ${skillName} resolves to zero valid install targets`);
  }
  return filtered;
}

function installSkill(skillDir) {
  const skillName = parseSkillName(path.join(skillDir, 'SKILL.md'));
  if (definedNames.has(skillName)) throw new Error(`Duplicate skill name ${skillName}`);
  definedNames.add(skillName);
  for (const targetBase of resolveTargetsForSkill(skillName)) {
    installTarget(path.join(targetBase, skillName), skillDir, targetBase);
    seenByTarget.get(targetBase).add(skillName);
  }
  installed.push({ name: skillName, source: skillDir });
}

pruneExternalRepos(config.third_party_repos || []);

for (const skillDir of collectLocalSkillDirs()) {
  installSkill(skillDir);
}

for (const repoConfig of config.third_party_repos || []) {
  for (const skillDir of resolveRepoSkillDirs(repoConfig)) {
    installSkill(skillDir);
  }
}

for (const targetBase of targets) {
  if (!fs.existsSync(targetBase)) continue;
  const seenHere = seenByTarget.get(targetBase) || new Set();
  for (const entry of fs.readdirSync(targetBase, { withFileTypes: true })) {
    const targetPath = path.join(targetBase, entry.name);
    if (!seenHere.has(entry.name) && (isManagedSymlink(targetPath) || isManagedCopy(targetPath))) {
      removeTarget(targetPath);
    }
  }
}

installed.sort((a, b) => a.name.localeCompare(b.name));
for (const item of installed) {
  process.stdout.write(`${item.name} -> ${item.source}\n`);
}
NODE
