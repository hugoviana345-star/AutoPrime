import 'design.dart';
import 'package:flutter/material.dart';
import 'produto_model.dart';
import 'api.dart';
import 'pagamento.dart';

class ItemCarrinho {
  final Produto produto;
  int quantidade;
  ItemCarrinho(this.produto, {this.quantidade = 1});
  double get subtotal => produto.preco * quantidade;
}

class CarrinhoDados extends ChangeNotifier {
  static final instancia = CarrinhoDados._();
  CarrinhoDados._();
  final List<ItemCarrinho> _itens = [];
  List<ItemCarrinho> get itens => List.unmodifiable(_itens);
  int get quantidade => _itens.fold(0, (s, i) => s + i.quantidade);
  double get total => _itens.fold(0.0, (s, i) => s + i.subtotal);

  Future<void> _fila = Future<void>.value();
  int _pendentes = 0;
  int _versao = 0;
  String? erro;
  bool get salvando => _pendentes > 0;

  Future<void> carregar() async {
    final dados = await Api.carregarCarrinho();
    final carregados = <ItemCarrinho>[];
    for (final item in dados) {
      final p = catalogo.where((p) => p.id == item['produto_id']);
      if (p.isNotEmpty) {
        carregados.add(ItemCarrinho(p.first, quantidade: item['quantidade'] as int));
      }
    }
    _itens..clear()..addAll(carregados);
    erro = null;
    notifyListeners();
  }

  void _salvar() {
    final dados = _itens.map((i) => <String, dynamic>{
      'produto_id': i.produto.id, 'quantidade': i.quantidade,
    }).toList();
    final versao = ++_versao;
    _pendentes++;
    erro = null;
    notifyListeners();
    // Salva em ordem, mesmo quando o usuário clica rapidamente.
    _fila = _fila.then((_) async {
      try {
        await Api.salvarCarrinho(dados);
        if (versao == _versao) erro = null;
      } catch (falha) {
        if (versao == _versao) erro = 'Carrinho ainda não salvo. $falha';
      } finally {
        _pendentes--;
        notifyListeners();
      }
    });
  }

  void tentarNovamente() => _salvar();

  Future<bool> aguardarSalvamento() async {
    await _fila;
    return erro == null;
  }

  // Limpa somente a tela ao sair, preservando o banco.
  void desconectar() {
    _itens.clear();
    erro = null;
    notifyListeners();
  }

  void adicionar(Produto produto, [int quantidade = 1]) {
    if (quantidade < 1 || quantidade > 999) return;
    final index = _itens.indexWhere((i) => i.produto.id == produto.id);
    if (index < 0) {
      _itens.add(ItemCarrinho(produto, quantidade: quantidade));
    } else {
      if (_itens[index].quantidade + quantidade > 999) return;
      _itens[index].quantidade += quantidade;
    }
    _salvar();
  }

  void alterar(ItemCarrinho item, int quantidade) {
    if (quantidade > 999) return;
    if (quantidade < 1) {
      _itens.remove(item);
    } else {
      item.quantidade = quantidade;
    }
    _salvar();
  }

  void limpar() {
    _itens.clear();
    _salvar();
  }
}

class CarrinhoIcone extends StatelessWidget {
  const CarrinhoIcone({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: CarrinhoDados.instancia,
    builder: (_, __) => Badge(
      isLabelVisible: CarrinhoDados.instancia.quantidade > 0,
      label: Text('${CarrinhoDados.instancia.quantidade}'),
      child: const Icon(Icons.shopping_cart_outlined),
    ),
  );
}

class CarrinhoPage extends StatelessWidget {
  const CarrinhoPage({super.key});

  Future<void> finalizar(BuildContext context) async {
    final carrinho = CarrinhoDados.instancia;
    if (carrinho.itens.isEmpty) return;
    if (!await carrinho.aguardarSalvamento() || !context.mounted) return;
    // O carrinho fica salvo ao abrir o banco e ao voltar para a loja.
    if (carrinho.itens.isEmpty) return;
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => PagamentoPage(
      total: carrinho.total, quantidade: carrinho.quantidade)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Meu carrinho')),
    body: ListenableBuilder(listenable: CarrinhoDados.instancia, builder: (context, _) {
      final c = CarrinhoDados.instancia;
      final estado = Row(children: [
        Icon(c.erro == null ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
          size: 16, color: c.erro == null ? const Color(0xff128c7e) : Colors.red),
        const SizedBox(width: 8), Expanded(child: Text(c.salvando ? 'Salvando alterações...' : c.erro ?? 'Carrinho salvo.',
          style: const TextStyle(fontSize: 12, color: primeMuted))),
        if (c.erro != null && !c.salvando) TextButton(onPressed: c.tentarNovamente, child: const Text('Tentar novamente')),
      ]);
      return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1140),
        child: SingleChildScrollView(padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const PageTitle('Suas escolhas.', 'Revise os produtos e ajuste as quantidades antes de continuar.'),
            if (c.itens.isEmpty) const PrimeCard(child: Padding(padding: EdgeInsets.all(48),
              child: Column(children: [Icon(Icons.shopping_cart_outlined, size: 56, color: primeMuted),
                SizedBox(height: 20), Text('Seu carrinho está vazio.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
                SizedBox(height: 8), Text('Abra Produtos e adicione seus itens favoritos.', textAlign: TextAlign.center,
                  style: TextStyle(color: primeMuted))])))
            else LayoutBuilder(builder: (context, constraints) {
              final itens = Column(children: [for (final item in c.itens) PrimeCard(
                child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
                  Row(children: [SizedBox(width: 80, child: ProdutoVisual(produto: item.produto, altura: 80)),
                    const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text(item.produto.nome, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4), Text(dinheiro(item.produto.preco), style: const TextStyle(color: primeMuted))])),
                    IconButton(tooltip: 'Remover produto', onPressed: () => c.alterar(item, 0), icon: const Icon(Icons.delete_outline))]),
                  const Divider(height: 28),
                  Wrap(alignment: WrapAlignment.spaceBetween, spacing: 24, runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(tooltip: 'Diminuir quantidade', onPressed: () => c.alterar(item, item.quantidade - 1),
                          icon: const Icon(Icons.remove)), Text('${item.quantidade}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        IconButton(tooltip: 'Aumentar quantidade', onPressed: item.quantidade < 999
                          ? () => c.alterar(item, item.quantidade + 1) : null, icon: const Icon(Icons.add))]),
                      Text(dinheiro(item.subtotal), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800))]),
                ]))) ]);
              final resumo = PrimeCard(child: Padding(padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Resumo do carrinho', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 24), Text('${c.quantidade} unidade(s)', style: const TextStyle(color: primeMuted)),
                  const Divider(height: 32), const Text('TOTAL', style: TextStyle(color: primeMuted, fontSize: 10, letterSpacing: 1.5)),
                  const SizedBox(height: 6), Text(dinheiro(c.total),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(onPressed: c.salvando || c.erro != null ? null : () => finalizar(context),
                    icon: const Icon(Icons.check_circle_outline, size: 20), label: const Text('Escolher pagamento')),
                  const SizedBox(height: 16), const Text('Escolha um banco ou carteira digital na próxima tela. Direcionamento demonstrativo, sem cobrança.',
                    style: TextStyle(fontSize: 12, color: primeMuted, height: 1.6)),
                ])));
              return constraints.maxWidth >= 820 ? Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(flex: 3, child: itens), const SizedBox(width: 24), Expanded(flex: 2, child: resumo)])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [itens, const SizedBox(height: 16), resumo]);
            }),
            const SizedBox(height: 16), estado,
          ]))));
    }));
}
