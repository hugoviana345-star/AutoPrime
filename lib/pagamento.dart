import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'design.dart';
import 'produto_model.dart';

class BancoPagamento {
  final String nome, sigla, url;
  final Color cor;
  const BancoPagamento({required this.nome, required this.sigla,
    required this.url, required this.cor});
}

// Direcionamento externo, igual ao projeto Senac.
// Para uma cobrança real, configure aqui um link de pagamento da loja.
// Não coloque senhas, tokens ou chaves secretas neste arquivo.
const bancosPagamento = <BancoPagamento>[
  BancoPagamento(nome: 'Mercado Pago', sigla: 'MP',
    url: 'https://www.mercadopago.com.br/', cor: Color(0xff009ee3)),
  BancoPagamento(nome: 'PicPay', sigla: 'P',
    url: 'https://picpay.com/', cor: Color(0xff21a65b)),
  BancoPagamento(nome: 'Banco Inter', sigla: 'I',
    url: 'https://inter.co/', cor: Color(0xffff7a00)),
  BancoPagamento(nome: 'Nubank', sigla: 'Nu',
    url: 'https://nubank.com.br/', cor: Color(0xff820ad1)),
];

class PagamentoPage extends StatefulWidget {
  final double total;
  final int quantidade;
  const PagamentoPage({super.key, required this.total, required this.quantidade});

  @override
  State<PagamentoPage> createState() => _PagamentoPageState();
}

class _PagamentoPageState extends State<PagamentoPage> {
  String? abrindo;

  Future<void> abrirBanco(BancoPagamento banco) async {
    if (abrindo != null) return;
    setState(() => abrindo = banco.nome);
    try {
      // Executado diretamente no clique: evita bloqueios de pop-up no Chrome.
      // Abrir o link não altera o carrinho e não confirma uma compra.
      final abriu = await launchUrl(Uri.parse(banco.url),
        mode: LaunchMode.externalApplication);
      if (!mounted) return;
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(
        content: Text(abriu
          ? 'Link de ${banco.nome} aberto. Seu carrinho continua salvo.'
          : 'Não foi possível abrir ${banco.nome}. Tente novamente.'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Não foi possível abrir ${banco.nome}. Tente novamente.'),
      ));
    } finally {
      if (mounted) setState(() => abrindo = null);
    }
  }

  Widget opcaoBanco(BancoPagamento banco) => PrimeCard(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: abrindo == null ? () => abrirBanco(banco) : null,
      child: Padding(padding: const EdgeInsets.all(20),
        child: Row(children: [
          Container(width: 50, height: 50,
            decoration: BoxDecoration(color: banco.cor, borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Text(banco.sigla, style: const TextStyle(color: Colors.white,
              fontSize: 19, fontWeight: FontWeight.w800))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(banco.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 4),
            Text(abrindo == banco.nome ? 'Abrindo...' : 'Abrir site externo',
              style: const TextStyle(color: primeMuted, fontSize: 12)),
          ])),
          const SizedBox(width: 12),
          if (abrindo == banco.nome)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else const Icon(Icons.open_in_new, color: primeMuted, size: 20),
        ])),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pagamento')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 850),
      child: SingleChildScrollView(padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PageTitle('Escolha onde continuar.', 'Toque em uma opção para abrir o site do banco ou da carteira digital.'),
          PrimeCard(child: Padding(padding: const EdgeInsets.all(24),
            child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 32, runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('SEU CARRINHO', style: TextStyle(color: primeMuted,
                    fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  const SizedBox(height: 8), Text('${widget.quantidade} unidade(s)'),
                ]),
                Text(dinheiro(widget.total), style: const TextStyle(fontWeight: FontWeight.w800,
                  fontSize: 32, letterSpacing: -1)),
              ]))),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xffeef2f8), borderRadius: BorderRadius.circular(14)),
            child: const Text('Demonstração: os botões abrem os sites das instituições. '
              'O valor do carrinho não é enviado e nenhum pagamento é confirmado.',
              style: TextStyle(color: primeMuted, fontSize: 13, height: 1.6))),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, constraints) {
            final duasColunas = constraints.maxWidth >= 650;
            return Wrap(spacing: 16, runSpacing: 8, children: [
              for (final banco in bancosPagamento)
                SizedBox(width: duasColunas ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                  child: opcaoBanco(banco)),
            ]);
          }),
          const SizedBox(height: 24),
          OutlinedButton.icon(onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 18), label: const Text('Voltar ao carrinho')),
        ])))),
  );
}
