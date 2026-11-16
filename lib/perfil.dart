import 'design.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'api.dart';

class PerfilPage extends StatefulWidget {
  final VoidCallback onSair;
  const PerfilPage({super.key, required this.onSair});
  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final dadosForm = GlobalKey<FormState>();
  final senhaForm = GlobalKey<FormState>();
  final nome = TextEditingController();
  final email = TextEditingController();
  final telefone = TextEditingController();
  final senhaEmail = TextEditingController();
  final senhaAtual = TextEditingController();
  final novaSenha = TextEditingController();
  final confirmarSenha = TextEditingController();
  bool carregando = true, salvando = false, ocultar = true;
  String? erroCarga;
  String emailSalvo = '', nomeSalvo = '';
  Uint8List? foto;
  bool get mudouEmail => email.text.trim().toLowerCase() != emailSalvo;

  @override
  void initState() {
    super.initState();
    if (!Api.visitante) carregar();
  }

  void preencher(Map<String, dynamic> perfil) {
    nome.text = perfil['nome'] as String;
    email.text = perfil['email'] as String;
    telefone.text = perfil['telefone'] as String;
    emailSalvo = email.text;
    nomeSalvo = nome.text;
    senhaEmail.clear();
    final imagem = perfil['foto'] as String? ?? '';
    foto = imagem.isEmpty ? null : base64Decode(imagem);
  }

  Future<void> carregar() async {
    setState(() { carregando = true; erroCarga = null; });
    try {
      final resposta = await Api.pedido('GET', '/me');
      if (!mounted) return;
      preencher(resposta['perfil'] as Map<String, dynamic>);
    } catch (erro) {
      if (mounted) erroCarga = '$erro';
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  void aviso(String mensagem) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Widget avatar(Uint8List? imagem, {double tamanho = 76}) => ClipOval(
    child: SizedBox(width: tamanho, height: tamanho,
      child: imagem == null
        ? CircleAvatar(backgroundColor: const Color(0xffd62828),
            child: Text(nomeSalvo.isEmpty ? '?' : nomeSalvo.substring(0,1).toUpperCase(),
              style: const TextStyle(fontSize: 28, color: Colors.white)))
        : Image.memory(imagem, fit: BoxFit.cover, gaplessPlayback: true,
            semanticLabel: 'Foto de perfil',
            errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xffeeeeee),
              child: Icon(Icons.person_outline, size: 36))),
    ),
  );

  Future<Uint8List> prepararFoto(Uint8List bytes) async {
    // Lê JPG/JPEG e PNG com o pacote image, sem usar ImageDescriptor.
    final decodificada = img.decodeImage(bytes, frame: 0);
    if (decodificada == null) {
      throw ErroApi('Não foi possível ler a foto. Escolha um arquivo JPEG, JPG ou PNG válido.');
    }
    final orientada = img.bakeOrientation(decodificada);
    final escala = math.min(1.0, math.min(256 / orientada.width, 256 / orientada.height));
    final miniatura = img.copyResize(orientada,
      width: math.max(1, (orientada.width * escala).round()),
      height: math.max(1, (orientada.height * escala).round()),
      interpolation: img.Interpolation.average,
    );
    // O servidor recebe um PNG de 8 bits com quatro canais.
    final rgba = miniatura.convert(format: img.Format.uint8,
      numChannels: 4, withPalette: false, noAnimation: true);
    final png = img.encodePng(rgba, singleFrame: true);
    if (png.length > 500 * 1024) throw ErroApi('Escolha uma foto menor.');
    return png;
  }

  Future<void> escolherFoto() async {
    if (salvando) return;
    setState(() => salvando = true);
    String etapa = 'abrir o seletor de fotos';
    try {
      // O seletor entrega o arquivo original. A conversão ocorre abaixo.
      final arquivo = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (arquivo == null || !mounted) return;
      if (await arquivo.length() > 10 * 1024 * 1024) {
        throw ErroApi('Escolha uma imagem de até 10 MB.');
      }
      etapa = 'ler o arquivo escolhido';
      final bytes = await arquivo.readAsBytes();
      etapa = 'preparar a imagem';
      final novaFoto = await prepararFoto(bytes);
      if (!mounted) return;
      final confirmar = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Usar esta foto?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          avatar(novaFoto, tamanho: 160),
          const SizedBox(height: 16),
          const Text('A foto será salva no seu perfil.', textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar foto')),
        ],
      ));
      if (confirmar != true || !mounted) return;
      etapa = 'salvar a foto no servidor';
      final resposta = await Api.pedido('PUT', '/me/photo', {'foto': base64Encode(novaFoto)});
      if (!mounted) return;
      foto = base64Decode(resposta['foto'] as String);
      aviso('Foto de perfil salva.');
    } on MissingPluginException {
      aviso('O seletor de fotos não foi carregado. Pare a execução e inicie novamente com py iniciar.py.');
    } catch (erro) {
      aviso(erro is ErroApi ? '$erro' : 'Falha ao $etapa. Detalhe: $erro');
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  Future<void> removerFoto() async {
    if (salvando || foto == null) return;
    final confirmar = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Remover foto?'),
      content: const Text('Seu perfil voltará a mostrar a inicial do seu nome.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
      ],
    ));
    if (!mounted || confirmar != true) return;
    setState(() => salvando = true);
    try {
      await Api.pedido('PUT', '/me/photo', {'foto': ''});
      if (!mounted) return;
      foto = null;
      aviso('Foto removida.');
    } catch (erro) {
      aviso('$erro');
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  Future<void> salvarDados() async {
    if (salvando || !dadosForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => salvando = true);
    try {
      final resposta = await Api.pedido('PUT', '/me', {
        'nome': nome.text.trim(), 'email': email.text.trim(),
        'telefone': telefone.text.trim(),
        if (mudouEmail) 'senha_atual': senhaEmail.text,
      });
      if (!mounted) return;
      preencher(resposta['perfil'] as Map<String, dynamic>);
      aviso('Dados do perfil salvos.');
    } catch (erro) {
      aviso('$erro');
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  Future<void> trocarSenha() async {
    if (salvando || !senhaForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => salvando = true);
    try {
      await Api.pedido('PUT', '/me', {
        'senha_atual': senhaAtual.text, 'nova_senha': novaSenha.text,
      });
      if (!mounted) return;
      senhaForm.currentState?.reset();
      senhaAtual.clear();
      novaSenha.clear();
      confirmarSenha.clear();
      aviso('Senha alterada. Use a nova senha no próximo login.');
    } catch (erro) {
      aviso('$erro');
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  @override
  void dispose() {
    for (final c in [nome, email, telefone, senhaEmail, senhaAtual, novaSenha, confirmarSenha]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Api.visitante) {
      return const Scaffold(body: Center(child: Text('Entre com uma conta para acessar o perfil.')));
    }
    final minimo = Api.administrador ? 8 : 6;
    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil'), actions: [
        IconButton(tooltip: 'Sair da conta', onPressed: salvando ? null : widget.onSair,
          icon: const Icon(Icons.logout)),
      ]),
      body: carregando ? const Center(child: CircularProgressIndicator())
        : erroCarga != null ? Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(erroCarga!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: carregar, child: const Text('Tentar novamente')),
            ])))
        : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(padding: const EdgeInsets.all(24), children: [
              const PageTitle('Sua conta, do seu jeito.', 'Atualize sua foto e mantenha seus dados em dia.'),
              PrimeCard(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
                Row(children: [
                  avatar(foto),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nomeSalvo.isEmpty ? 'Complete seu perfil' : nomeSalvo,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(emailSalvo, overflow: TextOverflow.ellipsis),
                    Text(Api.administrador ? 'Administrador' : 'Cliente', style: const TextStyle(color: Colors.grey)),
                  ])),
                ]),
                const SizedBox(height: 16),
                Wrap(spacing: 12, runSpacing: 8, alignment: WrapAlignment.center, children: [
                  OutlinedButton.icon(onPressed: salvando ? null : escolherFoto,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(foto == null ? 'Adicionar foto' : 'Trocar foto')),
                  if (foto != null) TextButton.icon(onPressed: salvando ? null : removerFoto,
                    icon: const Icon(Icons.delete_outline), label: const Text('Remover foto')),
                ]),
                if (salvando) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
              ]))),
              const SizedBox(height: 16),
              PrimeCard(child: Padding(padding: const EdgeInsets.all(24),
                child: Form(key: dadosForm, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Dados pessoais', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextFormField(controller: nome, enabled: !salvando,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => (v ?? '').trim().isEmpty || (v ?? '').trim().length > 100
                      ? 'Digite seu nome com até 100 caracteres.' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: telefone, enabled: !salvando,
                    keyboardType: TextInputType.phone, autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(labelText: 'Telefone (opcional)',
                      hintText: '(92) 99999-9999', prefixIcon: Icon(Icons.phone_outlined)),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      final digitos = t.replaceAll(RegExp(r'\D'), '').length;
                      return t.length > 30 || !RegExp(r'^[+0-9()\s.-]+$').hasMatch(t) || digitos < 10 || digitos > 15
                        ? 'Digite um telefone com 10 a 15 dígitos.' : null;
                    }),
                  const SizedBox(height: 16),
                  TextFormField(controller: email, enabled: !salvando,
                    keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined)),
                    validator: (v) => (v ?? '').trim().length > 254 || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((v ?? '').trim())
                      ? 'Digite um e-mail válido.' : null),
                  if (mudouEmail) ...[
                    const SizedBox(height: 16),
                    const Text('Para alterar o e-mail de acesso, confirme sua senha atual.'),
                    const SizedBox(height: 12),
                    TextFormField(controller: senhaEmail, enabled: !salvando, obscureText: true,
                      decoration: const InputDecoration(labelText: 'Senha atual', prefixIcon: Icon(Icons.lock_outline)),
                      validator: (v) => (v ?? '').isEmpty ? 'Digite sua senha atual.' : null),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(onPressed: salvando ? null : salvarDados,
                    icon: const Icon(Icons.save_outlined), label: Text(salvando ? 'Aguarde...' : 'Salvar dados')),
                ])),
              )),
              const SizedBox(height: 16),
              PrimeCard(child: Padding(padding: const EdgeInsets.all(24),
                child: Form(key: senhaForm, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Alterar senha', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Use uma nova senha com pelo menos $minimo caracteres.'),
                  const SizedBox(height: 20),
                  TextFormField(controller: senhaAtual, enabled: !salvando, obscureText: ocultar,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Senha atual', prefixIcon: Icon(Icons.lock_outline)),
                    validator: (v) => (v ?? '').isEmpty || (v ?? '').length > 128 ? 'Digite sua senha atual.' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: novaSenha, enabled: !salvando, obscureText: ocultar,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(labelText: 'Nova senha', prefixIcon: Icon(Icons.lock_reset)),
                    validator: (v) => (v ?? '').trim().length < minimo || (v ?? '').length > 128
                      ? 'Use de $minimo a 128 caracteres.' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: confirmarSenha, enabled: !salvando, obscureText: ocultar,
                    decoration: const InputDecoration(labelText: 'Confirmar nova senha', prefixIcon: Icon(Icons.lock_outline)),
                    validator: (v) => (v ?? '').isEmpty || v != novaSenha.text ? 'As senhas precisam ser iguais.' : null),
                  Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                    onPressed: salvando ? null : () => setState(() => ocultar = !ocultar),
                    icon: Icon(ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    label: Text(ocultar ? 'Mostrar senhas' : 'Ocultar senhas'))),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: salvando ? null : trocarSenha,
                    icon: const Icon(Icons.lock_reset), label: const Text('Alterar senha')),
                  const SizedBox(height: 12),
                  const Text('Alterar o e-mail ou a senha encerra os outros acessos à sua conta. Este acesso continua ativo.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                ])),
              )),
            ]),
          )),
    );
  }
}
