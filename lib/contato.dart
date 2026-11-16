import 'design.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'mapa.dart';

class ContatoPage extends StatefulWidget {
  const ContatoPage({super.key});
  @override
  State<ContatoPage> createState() => _ContatoPageState();
}

class _ContatoPageState extends State<ContatoPage> {
  final form = GlobalKey<FormState>();
  final nome = TextEditingController();
  final mensagem = TextEditingController();
  bool abrindo = false;
  static const numeroWhatsApp = '5592986094629';

  Future<void> abrirWhatsApp() async {
    if (abrindo || !form.currentState!.validate()) return;
    final texto = 'Olá! Estou entrando em contato pela AutoPrime.\n\n'
      'Meu nome é ${nome.text.trim()}.\n\n${mensagem.text.trim()}';
    final url = Uri.https('wa.me', '/$numeroWhatsApp', {'text': texto});
    setState(() => abrindo = true);
    try {
      final abriu = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!abriu && mounted) mostrarErro();
    } catch (_) {
      if (mounted) mostrarErro();
    } finally {
      if (mounted) setState(() => abrindo = false);
    }
  }

  void mostrarErro() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text('Não foi possível abrir o WhatsApp. Tente novamente.'),
    backgroundColor: Colors.red));

  @override
  void dispose() {
    nome.dispose();
    mensagem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Contato')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1140),
      child: SingleChildScrollView(padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const PageTitle('Como podemos ajudar?', 'Converse com a equipe ou consulte nosso ponto de referência no mapa.'),
          LayoutBuilder(builder: (context, constraints) {
            final formulario = PrimeCard(child: Padding(padding: const EdgeInsets.all(28),
              child: Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Row(children: [Icon(Icons.chat_bubble_outline, color: Color(0xff128c7e)),
                  SizedBox(width: 12), Expanded(child: Text('Fale com a AutoPrime',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 21)))]),
                const SizedBox(height: 12),
                const Text('Escreva sua mensagem. O botão abaixo abre a conversa no WhatsApp.',
                  style: TextStyle(color: primeMuted, fontSize: 13, height: 1.6)),
                const SizedBox(height: 24),
                TextFormField(controller: nome, textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Seu nome', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Digite seu nome.' : null),
                const SizedBox(height: 18),
                TextFormField(controller: mensagem, minLines: 5, maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Sua mensagem', alignLabelWithHint: true),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Digite sua mensagem.' : null),
                const SizedBox(height: 24),
                ElevatedButton.icon(onPressed: abrindo ? null : abrirWhatsApp,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff128c7e)),
                  icon: const Icon(Icons.send_outlined), label: Text(abrindo ? 'Abrindo...' : 'Conversar no WhatsApp')),
              ]))));
            return constraints.maxWidth >= 850 ? Row(crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: formulario), const SizedBox(width: 24),
                const Expanded(child: LocalizacaoCard())])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [formulario, const SizedBox(height: 18), const LocalizacaoCard()]);
          }),
        ])))));
}
