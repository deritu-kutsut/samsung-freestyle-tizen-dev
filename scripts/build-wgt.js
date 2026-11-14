#!/usr/bin/env node
/**
 * Empaqueta y firma un proyecto web de Tizen TV usando el mismo módulo que la
 * extensión tizentv, pero mostrando los errores reales de firma
 * (la extensión 1.3.3 los captura y no muestra nada).
 *
 * Uso:
 *   node build-wgt.js <carpeta_proyecto> <ruta_profiles.xml> [ruta_extension_tizentv]
 */
const fs = require('fs');
const path = require('path');
const os = require('os');

const [proyecto, perfiles, extArg] = process.argv.slice(2);
if (!proyecto || !perfiles) {
  console.error('Uso: node build-wgt.js <carpeta_proyecto> <ruta_profiles.xml> [ruta_extension_tizentv]');
  process.exit(64);
}

function buscarExtension() {
  if (extArg) return extArg;
  const dir = path.join(os.homedir(), '.vscode', 'extensions');
  const candidata = fs.readdirSync(dir).filter(n => n.startsWith('tizensdk.tizentv-')).sort().pop();
  if (!candidata) throw new Error('No se encontró la extensión tizensdk.tizentv en ' + dir);
  return path.join(dir, candidata);
}

(async () => {
  const ext = buscarExtension();
  const { TVWebApp } = require(path.join(ext, 'node_modules', '@tizentv', 'webide-common-tizentv'));
  const app = TVWebApp.openProject(path.resolve(proyecto));
  if (!app) {
    console.error('No es un proyecto Tizen válido (¿falta config.xml?).');
    process.exit(2);
  }
  await app.buildWidget(path.resolve(perfiles), '');
  console.log('BUILD_OK');
})().catch(e => {
  console.error('BUILD_ERROR: ' + ((e && e.message) || e));
  process.exit(1);
});
