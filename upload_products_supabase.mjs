import fs from 'fs';
import path from 'path';

const SUPABASE_URL = 'https://kblmdquushszqiqkriqd.supabase.co';
const SUPABASE_KEY = 'sb_publishable_28aAVuNjofV5db5lTcrScQ_SauSFP2p';

const CAT_MAP = {
  smd: '72cfbe7b-e27b-4d30-92c8-dcd0e3f20c66',
  pth: '54bd28c2-1ae1-4a48-a6de-2a864e4272bb',
  pcb: '1bd00e87-4d8f-48e0-ad18-fb952ac871cc',
  insumos: 'e98ee680-159c-432e-81a1-89c15298aa99',
  testedPlaca: 'c8af9210-7d92-419e-aa0f-9cfc79cb79ee',
  gabinetes: 'eed01e6c-8c86-45d2-a4ca-40861ade2466',
  sinalizacao: '9e60c0a9-dd14-4fc3-9101-b0df450d41cf',
  baterias: 'dcb0fada-6832-4dbc-bd17-6b1a058bc74a',
  embalagens: 'b1cfb2e6-d4d0-404c-93b0-769ec85a38e2',
  outros: '2dc2d0d4-636a-434b-aabc-21ea98530ecc'
};

function resolveCategory(product) {
  const name = product.name.toUpperCase();
  if (product.masterCategory === 'eletronica') {
    if (name.includes('SMD')) return CAT_MAP.smd;
    if (name.includes('SOLDA') || name.includes('FLUXO') || name.includes('ISOPROPILICO')) return CAT_MAP.insumos;
    if (name.includes('PCI') || name.includes('PCB')) return CAT_MAP.pcb;
    return CAT_MAP.pth;
  }
  if (product.masterCategory === 'producao') {
    if (name.includes('BATERIA') || name.includes('PILHA')) return CAT_MAP.baterias;
    if (name.includes('ADESIVO') || name.includes('CARTELA') || name.includes('ROTA') || name.includes('SINALIZACAO') || name.includes('SAIDA')) return CAT_MAP.sinalizacao;
    if (name.includes('CAIXA') || name.includes('LENTE') || name.includes('DIFUSOR') || name.includes('ESPELHO') || name.includes('GABINETE') || name.includes('SUPORTE')) return CAT_MAP.gabinetes;
    if (name.includes('PLACA')) return CAT_MAP.testedPlaca;
    return CAT_MAP.embalagens;
  }
  return CAT_MAP.outros;
}

async function uploadAll() {
  console.log('=== LUXPRYME STOCK - CARGA TOTAL DE PRODUTOS ===');

  let jsonPath = path.resolve('products_dataset.json');
  if (!fs.existsSync(jsonPath)) {
    jsonPath = 'C:/Users/I5-LUXPRYME/.gemini/antigravity/brain/aa1d1eb8-c71a-4442-b163-8514f67ac7f5/scratch/final_categorized_products.json';
  }

  const raw = fs.readFileSync(jsonPath, 'utf8');
  const products = JSON.parse(raw);
  console.log(`Total de produtos no arquivo: ${products.length}`);

  const counts = { eletronica: 0, producao: 0, outros: 0 };
  for (const p of products) {
    counts[p.masterCategory] = (counts[p.masterCategory] || 0) + 1;
  }
  console.log(`- Eletrônica (exclusivos): ${counts.eletronica}`);
  console.log(`- Produção: ${counts.producao}`);
  console.log(`- Outros: ${counts.outros}`);

  const headers = {
    'apikey': SUPABASE_KEY,
    'Authorization': `Bearer ${SUPABASE_KEY}`,
    'Content-Type': 'application/json',
    'Prefer': 'return=minimal'
  };

  // 1. Limpar produtos anteriores
  console.log('\n1. Limpando produtos anteriores no Supabase...');
  try {
    const delRes = await fetch(`${SUPABASE_URL}/rest/v1/products?id=not.is.null`, {
      method: 'DELETE',
      headers
    });
    console.log(`Status limpeza: ${delRes.status} ${delRes.statusText}`);
  } catch (err) {
    console.warn('Aviso limpeza:', err.message);
  }

  // 2. Inserir em lotes de 200
  const batchSize = 200;
  let insertedTotal = 0;
  console.log(`\n2. Inserindo ${products.length} produtos em lotes de ${batchSize}...`);

  for (let i = 0; i < products.length; i += batchSize) {
    const chunk = products.slice(i, i + batchSize).map(p => {
      const catId = resolveCategory(p);
      return {
        name: p.name,
        internal_code: p.codInt,
        code: p.code || null,
        barcode: p.barcode || null,
        master_categories: [p.masterCategory],
        category_id: catId,
        category_ids: [catId],
        quantity: p.quantity || 0,
        min_quantity: p.minQuantity || 10,
        location: p.location || 'Almoxarifado'
      };
    });

    const res = await fetch(`${SUPABASE_URL}/rest/v1/products`, {
      method: 'POST',
      headers,
      body: JSON.stringify(chunk)
    });

    if (!res.ok) {
      const errText = await res.text();
      console.error(`\nErro no lote ${i} a ${i + chunk.length}: [${res.status}] ${errText}`);
      throw new Error(`Falha na inserção: ${errText}`);
    } else {
      insertedTotal += chunk.length;
      const pct = Math.round((insertedTotal / products.length) * 100);
      process.stdout.write(`Progresso: ${insertedTotal} / ${products.length} inseridos (${pct}%)\r`);
    }
  }

  console.log(`\n\nSUCESSO TOTAL! ${insertedTotal} produtos inseridos com sucesso no Supabase!`);
}

uploadAll().catch(err => {
  console.error('\nErro na execução:', err);
  process.exit(1);
});
