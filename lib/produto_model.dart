import 'package:flutter/material.dart';
import 'api.dart';

class Produto {
  final String id;
  final String nome;
  final String descricao;
  final String categoria;
  final double preco;
  final String imagem;

  const Produto({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.preco,
    required this.categoria,
    required this.imagem,
  });
}

String dinheiro(double valor) {
  final partes = valor.toStringAsFixed(2).split('.');

  final inteiro = partes[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}.',
  );

  return 'R\$ $inteiro,${partes[1]}';
}

List<Produto> get catalogo => CatalogoDados.instancia.produtos;

class CatalogoDados extends ChangeNotifier {
  static final instancia = CatalogoDados._();
  CatalogoDados._();
  List<Produto> _produtos = [];
  List<Produto> get produtos => List.unmodifiable(_produtos);

  Future<void> carregar() async {
    final resposta = await Api.pedido('GET', '/products');
    final lista = (resposta['produtos'] as List).map((p) => Produto(
      id: p['id'] as String, nome: p['nome'] as String,
      descricao: p['descricao'] as String, categoria: p['categoria'] as String,
      preco: (p['preco'] as num).toDouble(), imagem: p['imagem'] as String,
    )).toList();
    _produtos = lista;
    notifyListeners();
  }
}

class ProdutoVisual extends StatelessWidget {
  final Produto produto;
  final double altura;

  const ProdutoVisual({
    super.key,
    required this.produto,
    this.altura = 168,
  });

  @override
  Widget build(BuildContext context) {
    final link = produto.imagem.trim();
    final miniatura = altura < 100;

    final aviso = Center(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Text(
          link.isEmpty ? 'Adicione a foto' : 'Foto indisponível',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: miniatura ? 10 : 14,
            color: Colors.grey,
          ),
        ),
      ),
    );

    return Container(
      height: altura,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xfff1f3f6)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.all(miniatura ? 4 : 14),
          child: link.isEmpty
              ? aviso
              : Image.network(
                  link,
                  width: double.infinity,
                  height: double.infinity,
                  // Exibe o produto inteiro, sem cortar nem distorcer.
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  semanticLabel: produto.nome,
                  errorBuilder: (context, erro, pilha) => aviso,
                  loadingBuilder: (context, child, progresso) {
                    if (progresso == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
