import '../models/category_model.dart';
import '../models/product_model.dart';

/// Categorias do Sistema
const List<CategoryModel> luxprymeDefaultCategories = [
  CategoryModel(
    id: 'cat-smd',
    name: 'Componentes SMD',
    description: 'Componentes para montagem em superfície',
  ),
  CategoryModel(
    id: 'cat-pth',
    name: 'Componentes PTH',
    description: 'Componentes de terminal passante',
  ),
  CategoryModel(
    id: 'cat-baterias',
    name: 'Baterias Industriais',
    description: 'Baterias e células de alimentação industrial',
  ),
  CategoryModel(
    id: 'cat-pcb',
    name: 'Placas de Circuito Impresso (PCBs)',
    description: 'Placas de circuito impresso virgens',
  ),
  CategoryModel(
    id: 'cat-board-smd',
    name: 'Placas com Componentes SMD',
    description: 'Placas montadas em superfície',
  ),
  CategoryModel(
    id: 'cat-board-pth',
    name: 'Placas com Componentes PTH',
    description: 'Placas com montagem e solda passante',
  ),
  CategoryModel(
    id: 'cat-board-tested',
    name: 'Placas Eletrônicas Testadas',
    description: 'Placas completas e testadas',
  ),
  CategoryModel(
    id: 'cat-insumos',
    name: 'Insumos e Químicos',
    description: 'Materiais e insumos de fabricação',
  ),
];

/// Lista inicial de produtos vazia para segurança e privacidade no repositório.
/// Os produtos são sincronizados em tempo real via Supabase ou carregados via seed local.
final List<ProductModel> luxprymeInitialProducts = [];
