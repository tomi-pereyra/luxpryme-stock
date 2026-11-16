-- ==============================================================================
-- LUXPRYME STOCK - SCRIPT ATUALIZADO E SEGURO DO BANCO DE DADOS (SUPABASE)
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
    ('Insumos e Químicos', 'Materiais e insumos de fabricação')
ON CONFLICT (name) DO NOTHING;

-- 2. Tabela de Produtos / Itens de Estoque
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    code TEXT,
    internal_code TEXT,
    manufacturer_code TEXT,
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    category_ids UUID[] DEFAULT ARRAY[]::UUID[],
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
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category_ids UUID[] DEFAULT ARRAY[]::UUID[];

-- 3. Tabela de PINs de Operadores para Baixa no Carrinho
CREATE TABLE IF NOT EXISTS public.operator_pins (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    pin VARCHAR(4) NOT NULL UNIQUE,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Inserir PINs Iniciais Padrão
INSERT INTO public.operator_pins (name, pin, is_active) VALUES
    ('Tomas (Supervisor de Eletrônica)', '2026', true),
    ('Roberto (Monitor de Linha)', '1234', true),
    ('Linha de Montagem SMD', '1111', true),
    ('Bancada PTH / Soldagem', '2222', true)
ON CONFLICT (pin) DO NOTHING;

-- 4. Tabela de Histórico de Movimentações de Estoque
CREATE TABLE IF NOT EXISTS public.stock_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL,
    product_code TEXT,
    internal_code TEXT,
    manufacturer_code TEXT,
    category_names TEXT[] DEFAULT ARRAY[]::TEXT[],
    delta INTEGER NOT NULL,
    previous_quantity INTEGER NOT NULL,
    new_quantity INTEGER NOT NULL,
    type TEXT NOT NULL,
    operator_name TEXT NOT NULL,
    pin_used TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

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

-- 6. Habilitar RLS (Row Level Security)
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.operator_pins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir leitura geral autenticados" ON public.categories;
CREATE POLICY "Permitir leitura geral autenticados" ON public.categories FOR ALL TO authenticated USING (true);

DROP POLICY IF EXISTS "Permitir leitura de produtos" ON public.products;
CREATE POLICY "Permitir leitura de produtos" ON public.products FOR ALL TO authenticated USING (true);

DROP POLICY IF EXISTS "Permitir leitura de pins" ON public.operator_pins;
CREATE POLICY "Permitir leitura de pins" ON public.operator_pins FOR ALL TO authenticated USING (true);

DROP POLICY IF EXISTS "Permitir leitura de movimentações" ON public.stock_movements;
CREATE POLICY "Permitir leitura de movimentações" ON public.stock_movements FOR ALL TO authenticated USING (true);

-- 7. Habilitar Realtime de Forma 100% Segura (Sem erro se já existir na publicação)
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.categories;
    EXCEPTION WHEN duplicate_object THEN
        -- Já está na publicação, ignora silenciosamente
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
    EXCEPTION WHEN duplicate_object THEN
        -- Já está na publicação, ignora silenciosamente
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.operator_pins;
    EXCEPTION WHEN duplicate_object THEN
        -- Já está na publicação, ignora silenciosamente
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.stock_movements;
    EXCEPTION WHEN duplicate_object THEN
        -- Já está na publicação, ignora silenciosamente
    END;
END $$;
