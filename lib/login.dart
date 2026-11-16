import 'design.dart';
import 'package:flutter/material.dart';
import 'inicio.dart';
import 'api.dart';
import 'produto_model.dart';
import 'carrinho.dart';

String? validarEmail(String? valor) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(valor?.trim() ?? '')
        ? null : 'Digite um e-mail válido.';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final senha = TextEditingController();
  bool ocultar = true;

  bool carregando = false;

  Future<void> entrar({bool visitante = false}) async {
    if (carregando) return;
    if (!visitante && !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => carregando = true);
    try {
      if (visitante) {
        await Api.entrarVisitante();
      } else {
        await Api.entrar(email.text.trim(), senha.text);
      }
      await CatalogoDados.instancia.carregar();
      await CarrinhoDados.instancia.carregar();
      if (!mounted) return;
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const InicioPage()));
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(erro.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  Future<void> criarConta() async {
    FocusScope.of(context).unfocus();
    final novoEmail = await Navigator.push<String>(context,
      MaterialPageRoute(builder: (_) => const CriarContaPage()));
    if (!mounted || novoEmail == null) return;
    form.currentState?.reset();
    email.text = novoEmail;
    senha.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Conta criada! Digite sua senha para entrar.'),
      backgroundColor: Colors.green));
  }

  @override
  void dispose() {
    email.dispose();
    senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AuthLayout(
      child: PrimeCard(child: Padding(
            padding: const EdgeInsets.all(28),
            child: Form(key: form, child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: PrimeBrand()),
                const SizedBox(height: 26),
                const Text('Bem-vindo de volta', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.7)),
                const SizedBox(height: 8),
                const Text('Entre na sua conta ou explore como visitante.', textAlign: TextAlign.center,
                  style: TextStyle(color: primeMuted)),
                const SizedBox(height: 30),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                    .hasMatch(v?.trim() ?? '') ? null : 'Digite um e-mail válido.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: senha, obscureText: ocultar,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => entrar(),
                  decoration: InputDecoration(labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: ocultar ? 'Mostrar senha' : 'Ocultar senha',
                      onPressed: () => setState(() => ocultar = !ocultar),
                      icon: Icon(ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
                  validator: (v) => v == null || v.isEmpty ? 'Digite sua senha.' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: carregando ? null : () => entrar(),
                  child: Text(carregando ? 'Conectando...' : 'Entrar')),
                const SizedBox(height: 8),
                TextButton(onPressed: carregando ? null : criarConta,
                  child: const Text('Não tem uma conta? Criar conta')),
                const SizedBox(height: 16),
                const Row(children: [
                  Expanded(child: Divider()),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('ou', style: TextStyle(color: Colors.grey))),
                  Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: carregando ? null : () => entrar(visitante: true),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Continuar como visitante'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            )),
          )),
    ),
  );
}

class CriarContaPage extends StatefulWidget {
  const CriarContaPage({super.key});
  @override
  State<CriarContaPage> createState() => _CriarContaPageState();
}

class _CriarContaPageState extends State<CriarContaPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final senha = TextEditingController();
  final confirmarSenha = TextEditingController();
  bool ocultar = true;

  bool salvando = false;

  Future<void> cadastrar() async {
    if (salvando || !form.currentState!.validate()) return;
    setState(() => salvando = true);
    try {
      await Api.cadastrar(email.text.trim().toLowerCase(), senha.text);
      if (mounted) Navigator.pop(context, email.text.trim().toLowerCase());
    } catch (erro) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    senha.dispose();
    confirmarSenha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Criar conta')),
    body: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: PrimeCard(child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(key: form, child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.person_add_outlined, size: 64, color: Color(0xffd62828)),
              const SizedBox(height: 12),
              const Text('Sua conta AutoPrime', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined)),
                validator: (v) {
                  final erro = validarEmail(v);
                  if (erro != null) return erro;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: senha, obscureText: ocultar,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: 'Senha',
                  helperText: 'Use pelo menos 6 caracteres.',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: ocultar ? 'Mostrar senhas' : 'Ocultar senhas',
                    onPressed: () => setState(() => ocultar = !ocultar),
                    icon: Icon(ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
                validator: (v) => (v ?? '').trim().length < 6
                  ? 'Use pelo menos 6 caracteres.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmarSenha, obscureText: ocultar,
                onFieldSubmitted: (_) => cadastrar(),
                decoration: const InputDecoration(labelText: 'Confirmar senha',
                  prefixIcon: Icon(Icons.lock_outline)),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirme sua senha.';
                  return v != senha.text ? 'As senhas não são iguais.' : null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: salvando ? null : cadastrar,
                child: Text(salvando ? 'Salvando...' : 'Criar conta')),
              const SizedBox(height: 16),
              const Text('Sua conta será salva para os próximos acessos.', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          )),
        )),
      ),
    )),
  );
}
