const fs = require('fs');
const { cleanEdgeGarbage } = require('./clean_edge_garbage');

function cleanFile(path) {
  const raw = fs.readFileSync(path, 'utf8');
  const clean = cleanEdgeGarbage(raw);
  fs.writeFileSync(path, clean, 'utf8');
}

cleanFile(process.argv[2]);

