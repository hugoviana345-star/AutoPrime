import 'package:flutter/material.dart';
import 'produto_model.dart';
import 'carrinho.dart';
import 'produtos.dart';
import 'design.dart';

class DetalhesPage extends StatefulWidget {
  final Produto produto;
  const DetalhesPage({super.key, required this.produto});
  @override
  State<DetalhesPage> createState() => _DetalhesPageState();
}
class _DetalhesPageState extends State<DetalhesPage> {
  int quantidade = 1;
  @override
  Widget build(BuildContext context) {
    final p = widget.produto;
    return Scaffold(appBar: AppBar(title: const Text('Detalhes do produto'), actions: [
      IconButton(tooltip: 'Abrir carrinho', icon: const CarrinhoIcone(), onPressed: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const CarrinhoPage()))), const SizedBox(width: 16)]),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1140),
        child: SingleChildScrollView(padding: const EdgeInsets.all(24),
          child: LayoutBuilder(builder: (context, constraints) {
            final largo = constraints.maxWidth >= 760;
            final imagem = PrimeCard(child: Padding(padding: const EdgeInsets.all(24),
              child: ProdutoVisual(produto: p, altura: largo ? 410 : 250)));
            final info = PrimeCard(child: Padding(padding: const EdgeInsets.all(28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(p.categoria.toUpperCase(), style: const TextStyle(color: primeRed,
                  fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                Text(p.nome, style: const TextStyle(fontSize: 32, height: 1.15,
                  fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                const SizedBox(height: 20),
                Text(p.descricao, style: const TextStyle(color: primeMuted, height: 1.7)),
                const SizedBox(height: 24),
                Text(dinheiro(p.preco), style: const TextStyle(fontSize: 36,
                  fontWeight: FontWeight.w800, letterSpacing: -1)),
                const SizedBox(height: 4), const Text('Preço por unidade', style: TextStyle(color: primeMuted, fontSize: 12)),
                const Divider(height: 40),
                Row(children: [const Expanded(child: Text('Quantidade', style: TextStyle(fontWeight: FontWeight.w600))),
                  IconButton(tooltip: 'Diminuir quantidade', onPressed: quantidade > 1 ? () => setState(() => quantidade--) : null,
                    icon: const Icon(Icons.remove)), Text('$quantidade', style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(tooltip: 'Aumentar quantidade', onPressed: quantidade < 999 ? () => setState(() => quantidade++) : null,
                    icon: const Icon(Icons.add))]),
                const SizedBox(height: 20),
                ElevatedButton.icon(onPressed: () => adicionarProduto(context, p, quantidade),
                  icon: const Icon(Icons.add_shopping_cart_outlined), label: const Text('Adicionar ao carrinho')),
                const SizedBox(height: 12), Text('Subtotal: ${dinheiro(p.preco * quantidade)}', textAlign: TextAlign.center,
                  style: const TextStyle(color: primeMuted, fontSize: 13)),
                const SizedBox(height: 24),
                Container(padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: primeBackground, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Confira a compatibilidade com o modelo e o ano do seu veículo antes de comprar.',
                    style: TextStyle(color: primeMuted, fontSize: 12, height: 1.6))),
              ])));
            return largo ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: imagem), const SizedBox(width: 24), Expanded(child: info)])
              : Column(children: [imagem, const SizedBox(height: 16), info]);
          })))));
  }
}
