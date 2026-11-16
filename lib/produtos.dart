import 'package:flutter/material.dart';
import 'produto_model.dart';
import 'detalhes.dart';
import 'carrinho.dart';
import 'design.dart';

// O mesmo cartão é usado na página inicial e no catálogo.
class ProdutoCard extends StatefulWidget {
  final Produto produto;
  const ProdutoCard({super.key, required this.produto});
  @override
  State<ProdutoCard> createState() => _ProdutoCardState();
}

class _ProdutoCardState extends State<ProdutoCard> {
  bool hover = false;
  void detalhes() => Navigator.push(context,
    MaterialPageRoute(builder: (_) => DetalhesPage(produto: widget.produto)));
  @override
  Widget build(BuildContext context) {
    final p = widget.produto;
    return MouseRegion(onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: AnimatedContainer(duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: hover ? const Color(0xffd0d5dd) : primeLine),
          boxShadow: hover ? [const BoxShadow(color: Color(0x0d17202f), blurRadius: 24, offset: Offset(0, 8))] : []),
        child: Padding(padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InkWell(onTap: detalhes, borderRadius: BorderRadius.circular(14),
              child: ProdutoVisual(produto: p, altura: 168)),
            const SizedBox(height: 18),
            Text(p.categoria.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, letterSpacing: 1.3, color: primeMuted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(p.nome, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, height: 1.3, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(p.descricao, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: primeMuted, fontSize: 12, height: 1.5)),
            const Spacer(),
            Text(dinheiro(p.preco), style: const TextStyle(fontSize: 25,
              letterSpacing: -0.8, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ElevatedButton.icon(onPressed: () => adicionarProduto(context, p),
              icon: const Icon(Icons.add_shopping_cart_outlined, size: 18), label: const Text('Adicionar')),
            TextButton(onPressed: detalhes, child: const Text('Ver detalhes')),
          ]))));
  }
}

void adicionarProduto(BuildContext context, Produto produto, [int quantidade = 1]) {
  final c = CarrinhoDados.instancia;
  final atuais = c.itens.where((i) => i.produto.id == produto.id)
    .fold<int>(0, (total, i) => total + i.quantidade);
  final limite = atuais + quantidade > 999;
  if (!limite) c.adicionar(produto, quantidade);
  ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(
    content: Text(limite ? 'O limite é de 999 unidades por produto.' : '${produto.nome} adicionado ao carrinho.')));
}

class ProdutosPage extends StatefulWidget {
  const ProdutosPage({super.key});
  @override
  State<ProdutosPage> createState() => _ProdutosPageState();
}
class _ProdutosPageState extends State<ProdutosPage> {
  String busca = '', categoria = 'Todas', ordem = 'Nome';
  final pesquisa = TextEditingController();
  @override
  void dispose() { pesquisa.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: CatalogoDados.instancia,
    builder: (context, _) => construir(context));
  Widget construir(BuildContext context) {
    if (categoria != 'Todas' && !catalogo.any((p) => p.categoria == categoria)) categoria = 'Todas';
    final produtos = catalogo.where((p) => (categoria == 'Todas' || p.categoria == categoria) &&
      '${p.nome} ${p.descricao} ${p.categoria}'.toLowerCase().contains(busca)).toList();
    produtos.sort((a, b) => ordem == 'Menor preço' ? a.preco.compareTo(b.preco)
      : ordem == 'Maior preço' ? b.preco.compareTo(a.preco) : a.nome.compareTo(b.nome));
    return Scaffold(appBar: AppBar(title: const Text('Catálogo'), actions: [
      IconButton(tooltip: 'Abrir carrinho', icon: const CarrinhoIcone(), onPressed: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const CarrinhoPage()))), const SizedBox(width: 16)]),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1240),
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const PageTitle('Encontre a peça certa.', 'Pesquise, compare e escolha o que seu carro precisa.'),
              TextField(controller: pesquisa, onChanged: (v) => setState(() => busca = v.trim().toLowerCase()),
                decoration: InputDecoration(hintText: 'Buscar por produto ou categoria', prefixIcon: const Icon(Icons.search),
                  suffixIcon: busca.isEmpty ? null : IconButton(tooltip: 'Limpar busca', icon: const Icon(Icons.close),
                    onPressed: () { pesquisa.clear(); setState(() => busca = ''); }))),
              const SizedBox(height: 20),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                for (final c in ['Todas', ...catalogo.map((p) => p.categoria).toSet()])
                  Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                    showCheckmark: false, label: Text(c), selected: categoria == c,
                    onSelected: (_) => setState(() => categoria = c)))])),
              const SizedBox(height: 18),
              Wrap(spacing: 24, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('${produtos.length} produtos encontrados', style: const TextStyle(color: primeMuted)),
                DropdownButton<String>(value: ordem, underline: const SizedBox.shrink(),
                  items: ['Nome', 'Menor preço', 'Maior preço'].map((v) => DropdownMenuItem(value: v,
                    child: Text('Ordenar: $v', style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => ordem = v ?? 'Nome'))]),
            ]))),
          if (produtos.isEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(40),
            child: Column(children: [const Icon(Icons.search_off, size: 48, color: primeMuted),
              const SizedBox(height: 16), const Text('Nenhum produto encontrado.'),
              TextButton(onPressed: () { pesquisa.clear(); setState(() { busca = ''; categoria = 'Todas'; }); },
                child: const Text('Limpar filtros'))]))),
          SliverPadding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            sliver: SliverLayoutBuilder(builder: (context, constraints) {
              final w = constraints.crossAxisExtent;
              return SliverGrid(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: w >= 1100 ? 4 : w >= 820 ? 3 : w >= 540 ? 2 : 1,
                mainAxisExtent: 500 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 16, mainAxisSpacing: 20, crossAxisSpacing: 20),
                delegate: SliverChildBuilderDelegate((context, i) => ProdutoCard(produto: produtos[i]),
                  childCount: produtos.length));
            })),
        ]))));
  }
}
