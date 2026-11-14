// Empaqueta y firma un proyecto web de Tizen TV con el módulo de la extensión tizentv,
// mostrando los errores reales (la extensión 1.3.3 los oculta).
// Uso: node build-wgt.js <proyecto> <profiles.xml> <carpeta_extension_tizentv>
const path = require('path');

const [proyecto, perfiles, ext] = process.argv.slice(2);
if (!proyecto || !perfiles || !ext) {
  console.error('Uso: node build-wgt.js <proyecto> <profiles.xml> <carpeta_extension_tizentv>');
  process.exit(64);
}

// Si la firma falla, la extensión traga el error y la promesa nunca termina: el proceso sale sin BUILD_OK.
(async () => {
  const { TVWebApp } = require(path.join(ext, 'node_modules', '@tizentv', 'webide-common-tizentv'));
  const app = TVWebApp.openProject(path.resolve(proyecto));
  if (!app) { console.error('No es un proyecto Tizen válido (falta config.xml).'); process.exit(2); }
  const limite = setTimeout(() => { console.error('BUILD_TIMEOUT: la firma no terminó (¿contraseña o perfil inválidos?)'); process.exit(3); }, 120000);
  limite.unref();
  await app.buildWidget(path.resolve(perfiles), '');
  clearTimeout(limite);
  console.log('BUILD_OK');
})().catch(e => { console.error('BUILD_ERROR: ' + ((e && e.message) || e)); process.exit(1); });
