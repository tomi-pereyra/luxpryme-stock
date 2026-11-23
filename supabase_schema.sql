-- ==============================================================================
-- LUXPRYME STOCK - SCRIPT ATUALIZADO DO BANCO DE DADOS (SUPABASE)
-- Execute este script no menu "SQL Editor" do seu painel do Supabase
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Tabela de Categorias Industriais
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Inserção das Categorias Padrão
INSERT INTO public.categories (name, description) VALUES
    ('Componentes SMD', 'Componentes para montagem em superfície'),
    ('Componentes PTH', 'Componentes de terminal passante'),
    ('Baterias Industriais', 'Baterias e células de alimentação industrial'),
    ('Placas de Circuito Impresso (PCBs)', 'Placas de circuito impresso virgens'),
    ('Placas com Componentes SMD', 'Placas montadas em superfície'),
    ('Placas com Componentes PTH', 'Placas com montagem e solda passante'),
    ('Placas Eletrônicas Testadas', 'Placas completas e testadas'),
    ('Insumos de Solda e Químicos', 'Materiais e insumos de fabricação'),
    ('Gabinetes e Injeção Plástica', 'Caixas plásticas, lentes, visores e suportes'),
    ('Sinalização e Adesivos', 'Cartelas fotoluminescentes e rotas de fuga'),
    ('Embalagens e Fixações', 'Caixas coletivas, individuais e parafusos')
ON CONFLICT (name) DO NOTHING;

-- 2. Limpar produtos antigos para carga do zero (Conforme solicitado)
TRUNCATE TABLE public.products CASCADE;

-- Tabela de Produtos / Itens de Estoque
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    code TEXT,
    internal_code TEXT,
    manufacturer_code TEXT,
    barcode TEXT,
    master_categories TEXT[] DEFAULT ARRAY['eletronica']::TEXT[],
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    category_ids UUID[] DEFAULT ARRAY[]::UUID[],
    subcategories TEXT[] DEFAULT ARRAY[]::TEXT[],
    subcategory TEXT,
    quantity INTEGER NOT NULL DEFAULT 0,
    min_quantity INTEGER NOT NULL DEFAULT 10,
    location TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT check_quantity_not_negative CHECK (quantity >= 0)
);

-- Migração Segura: Adiciona novas colunas caso a tabela já existisse
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS internal_code TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS manufacturer_code TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS barcode TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS master_categories TEXT[] DEFAULT ARRAY['eletronica']::TEXT[];
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category_ids UUID[] DEFAULT ARRAY[]::UUID[];
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS subcategories TEXT[] DEFAULT ARRAY[]::TEXT[];
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS subcategory TEXT;

-- 3. Tabela de PINs de Operadores para Baixa no Carrinho
CREATE TABLE IF NOT EXISTS public.operator_pins (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    pin VARCHAR(4) NOT NULL UNIQUE,
    master_category TEXT NOT NULL DEFAULT 'eletronica',
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Migração Segura: Adiciona master_category caso a tabela já existisse
ALTER TABLE public.operator_pins ADD COLUMN IF NOT EXISTS master_category TEXT NOT NULL DEFAULT 'eletronica';

-- Inserir / Atualizar PINs Iniciais com seus Setores Autorizados
INSERT INTO public.operator_pins (name, pin, master_category, is_active) VALUES
    ('Claumir (Gerente Operacional)', '2026', 'todas', true),
    ('Tomas (Supervisor de Eletrônica)', '4464', 'todas', true),
    ('Roberto (Monitor SMD)', '1830', 'eletronica', true),
    ('Novachelande (Monitora PTH)', '1206', 'eletronica', true),
    ('Julia', '4512', 'eletronica', true)
ON CONFLICT (pin) DO UPDATE SET 
    name = EXCLUDED.name,
    master_category = EXCLUDED.master_category,
    is_active = EXCLUDED.is_active;

-- 4. Tabela de Histórico de Movimentações de Estoque
CREATE TABLE IF NOT EXISTS public.stock_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL,
    product_code TEXT,
    internal_code TEXT,
    manufacturer_code TEXT,
    category_names TEXT[] DEFAULT ARRAY[]::TEXT[],
    master_categories TEXT[] DEFAULT ARRAY[]::TEXT[],
    delta INTEGER NOT NULL,
    previous_quantity INTEGER NOT NULL,
    new_quantity INTEGER NOT NULL,
    type TEXT NOT NULL,
    operator_name TEXT NOT NULL,
    pin_used TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.stock_movements ADD COLUMN IF NOT EXISTS master_categories TEXT[] DEFAULT ARRAY[]::TEXT[];
ALTER TABLE public.stock_movements ADD COLUMN IF NOT EXISTS notes TEXT;

-- 5. Função e Trigger para atualizar updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_products_updated_at ON public.products;
CREATE TRIGGER trigger_products_updated_at
    BEFORE UPDATE ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- 6. Habilitar RLS e Permissões Robustas
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.operator_pins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir leitura geral categorias" ON public.categories;
DROP POLICY IF EXISTS "Permitir leitura geral autenticados" ON public.categories;
CREATE POLICY "Permitir leitura geral categorias" ON public.categories FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir leitura de produtos" ON public.products;
DROP POLICY IF EXISTS "Permitir acesso geral a produtos" ON public.products;
CREATE POLICY "Permitir acesso geral a produtos" ON public.products FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir leitura de pins" ON public.operator_pins;
DROP POLICY IF EXISTS "Permitir acesso geral a operator_pins" ON public.operator_pins;
CREATE POLICY "Permitir acesso geral a operator_pins" ON public.operator_pins FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir leitura de movimentações" ON public.stock_movements;
DROP POLICY IF EXISTS "Permitir leitura e escrita pública de movimentações" ON public.stock_movements;
DROP POLICY IF EXISTS "Permitir acesso geral a movimentações" ON public.stock_movements;
CREATE POLICY "Permitir acesso geral a movimentações" ON public.stock_movements FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);

-- 8. Tabela de Categorias Mestres Dinâmicas
CREATE TABLE IF NOT EXISTS public.master_categories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    color TEXT,
    icon TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

INSERT INTO public.master_categories (id, name, description, color, icon) VALUES
    ('eletronica', 'Eletrônica', 'Componentes eletrônicos, semicondutores, PCBs e insumos de eletrônica', '#2563EB', 'memory'),
    ('producao', 'Produção', 'Componentes e insumos utilizados na montagem do produto final', '#059669', 'precision_manufacturing'),
    ('outros', 'Outros', 'Insumos gerais, manutenção predial e civil', '#64748B', 'inventory_2')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    color = EXCLUDED.color,
    icon = EXCLUDED.icon;

ALTER TABLE public.master_categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir acesso geral a master_categories" ON public.master_categories;
CREATE POLICY "Permitir acesso geral a master_categories" ON public.master_categories FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);

-- 7. Habilitar Realtime
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.categories;
    EXCEPTION WHEN duplicate_object THEN
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
    EXCEPTION WHEN duplicate_object THEN
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.operator_pins;
    EXCEPTION WHEN duplicate_object THEN
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.stock_movements;
    EXCEPTION WHEN duplicate_object THEN
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.master_categories;
    EXCEPTION WHEN duplicate_object THEN
    END;
END $$;
