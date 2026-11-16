import 'design.dart';
import 'package:flutter/material.dart';
import 'api.dart';
import 'produto_model.dart';
import 'carrinho.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool ocupado = false;
  String busca = '';

  void aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> atualizar() async {
    if (ocupado) return;
    setState(() => ocupado = true);
    try {
      if (!await CarrinhoDados.instancia.aguardarSalvamento()) {
        throw ErroApi('Salve o carrinho antes de atualizar os produtos.');
      }
      await CatalogoDados.instancia.carregar();
      await CarrinhoDados.instancia.carregar();
    } catch (erro) {
      aviso('$erro');
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> editar([Produto? produto]) async {
    if (ocupado) return;
    final mudou = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => ProdutoFormularioPage(produto: produto)));
    if (!mounted || mudou != true) return;
    await atualizar();
  }

  Future<void> excluir(Produto p) async {
    if (ocupado) return;
    final confirmar = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Excluir produto?'),
      content: Text('${p.nome} será retirado do catálogo e dos carrinhos. Esta ação não pode ser desfeita pela tela.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Excluir', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (!mounted || confirmar != true) return;
    setState(() => ocupado = true);
    bool excluido = false;
    try {
      if (!await CarrinhoDados.instancia.aguardarSalvamento()) {
        throw ErroApi('Salve o carrinho antes de excluir o produto.');
      }
      await Api.pedido('DELETE', '/products/${p.id}');
      excluido = true;
      await CatalogoDados.instancia.carregar();
      await CarrinhoDados.instancia.carregar();
      aviso('Produto excluído.');
    } catch (erro) {
      aviso(excluido ? 'Produto excluído, mas a atualização falhou. Toque em Atualizar. $erro' : '$erro');
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Api.administrador) {
      return const Scaffold(body: Center(child: Text('Acesso exclusivo para administradores.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Administração'), actions: [
        IconButton(tooltip: 'Atualizar', onPressed: ocupado ? null : atualizar,
          icon: const Icon(Icons.refresh)),
      ]),
      body: ListenableBuilder(listenable: CatalogoDados.instancia, builder: (context, _) {
        final produtos = catalogo.where((p) => '${p.nome} ${p.categoria}'.toLowerCase().contains(busca)).toList();
        return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const PageTitle('Gerencie seu catálogo.', 'Cadastre e edite produtos. As mudanças aparecem para os clientes ao entrar novamente.'),
            const SizedBox(height: 16),
            PrimeCard(child: Padding(padding: const EdgeInsets.all(20), child: Wrap(
              spacing: 28, runSpacing: 12, children: [
                Text('${catalogo.length} produto(s)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('${catalogo.map((p) => p.categoria).toSet().length} categoria(s)'),
              ],
            ))),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: ocupado ? null : () => editar(),
              icon: const Icon(Icons.add), label: const Text('Cadastrar produto')),
            const SizedBox(height: 16),
            TextField(onChanged: (v) => setState(() => busca = v.trim().toLowerCase()),
              decoration: const InputDecoration(labelText: 'Buscar produto ou categoria', prefixIcon: Icon(Icons.search))),
            const SizedBox(height: 16),
            if (ocupado) const LinearProgressIndicator(),
            if (produtos.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Nenhum produto encontrado.')),
            for (final p in produtos)
              PrimeCard(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                Row(children: [
                  SizedBox(width: 76, child: ProdutoVisual(produto: p, altura: 76)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(p.categoria),
                    Text(dinheiro(p.preco), style: const TextStyle(color: Color(0xffd62828), fontWeight: FontWeight.bold)),
                  ])),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 12, children: [
                  OutlinedButton.icon(onPressed: ocupado ? null : () => editar(p),
                    icon: const Icon(Icons.edit_outlined), label: const Text('Editar')),
                  TextButton.icon(onPressed: ocupado ? null : () => excluir(p),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Excluir', style: TextStyle(color: Colors.red))),
                ]),
              ]))),
          ]),
        ));
      }),
    );
  }
}

class ProdutoFormularioPage extends StatefulWidget {
  final Produto? produto;
  const ProdutoFormularioPage({super.key, this.produto});
  @override
  State<ProdutoFormularioPage> createState() => _ProdutoFormularioPageState();
}

class _ProdutoFormularioPageState extends State<ProdutoFormularioPage> {
  final form = GlobalKey<FormState>();
  final nome = TextEditingController();
  final descricao = TextEditingController();
  final categoria = TextEditingController();
  final preco = TextEditingController();
  final imagem = TextEditingController();
  bool salvando = false;
  bool gravado = false;

  @override
  void initState() {
    super.initState();
    final p = widget.produto;
    if (p != null) {
      nome.text = p.nome;
      descricao.text = p.descricao;
      categoria.text = p.categoria;
      preco.text = p.preco.toStringAsFixed(2).replaceAll('.', ',');
      imagem.text = p.imagem;
    }
  }

  @override
  void dispose() {
    for (final c in [nome, descricao, categoria, preco, imagem]) { c.dispose(); }
    super.dispose();
  }

  String? textoValido(String? valor, int limite) {
    final t = valor?.trim() ?? '';
    return t.isEmpty || t.length > limite ? 'Preencha com até $limite caracteres.' : null;
  }

  String? precoValido(String? valor) {
    final texto = (valor ?? '').trim().replaceAll(',', '.');
    final numero = double.tryParse(texto);
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(texto) || numero == null || numero <= 0 || numero > 999999.99) {
      return 'Use um valor entre 0,01 e 999999,99, sem separador de milhar.';
    }
    return null;
  }

  Future<void> salvar() async {
    if (salvando || !Api.administrador) return;
    if (!gravado && !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => salvando = true);
    try {
      if (!await CarrinhoDados.instancia.aguardarSalvamento()) {
        throw ErroApi('Salve o carrinho antes de alterar os produtos.');
      }
      if (!gravado) {
        final p = widget.produto;
        await Api.pedido(p == null ? 'POST' : 'PUT', p == null ? '/products' : '/products/${p.id}', {
          'nome': nome.text.trim(), 'descricao': descricao.text.trim(),
          'categoria': categoria.text.trim(), 'preco': preco.text.trim().replaceAll(',', '.'),
          'imagem': imagem.text.trim(),
        });
        gravado = true;
      }
      // Se a atualização falhar após gravar, o botão apenas recarrega,
      // evitando cadastrar o mesmo produto novamente nesta tela.
      await CatalogoDados.instancia.carregar();
      await CarrinhoDados.instancia.carregar();
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto salvo.')));
    } catch (erro) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        gravado ? 'Produto salvo, mas a atualização falhou. Toque em Atualizar catálogo. $erro' : '$erro')));
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !salvando,
    child: Scaffold(
      appBar: AppBar(title: Text(widget.produto == null ? 'Cadastrar produto' : 'Editar produto')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 650),
        child: SingleChildScrollView(padding: const EdgeInsets.all(24),
          child: Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(controller: nome, enabled: !salvando && !gravado,
              decoration: const InputDecoration(labelText: 'Nome do produto'), validator: (v) => textoValido(v,100)),
            const SizedBox(height: 16),
            TextFormField(controller: categoria, enabled: !salvando && !gravado,
              decoration: const InputDecoration(labelText: 'Categoria', hintText: 'Ex.: Acessórios'), validator: (v) => textoValido(v,60)),
            const SizedBox(height: 16),
            TextFormField(controller: preco, enabled: !salvando && !gravado,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Preço (R\$)', hintText: 'Ex.: 189,90'), validator: precoValido),
            const SizedBox(height: 16),
            TextFormField(controller: descricao, enabled: !salvando && !gravado, minLines: 3, maxLines: 6,
              decoration: const InputDecoration(labelText: 'Descrição'), validator: (v) => textoValido(v,2000)),
            const SizedBox(height: 16),
            TextFormField(controller: imagem, enabled: !salvando && !gravado, keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Link direto da imagem (opcional)', hintText: 'https://.../foto.jpg'),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final u = Uri.tryParse(t);
                return t.length > 2000 || u == null || !['http','https'].contains(u.scheme) || u.host.isEmpty || u.userInfo.isNotEmpty
                  ? 'Use um link válido começando com http:// ou https://.' : null;
              }),
            const SizedBox(height: 8),
            const Text('Cole o endereço da foto, não o endereço da página do produto.'),
            const SizedBox(height: 16),
            ProdutoVisual(altura: 200, produto: Produto(id: '', nome: nome.text,
              descricao: '', categoria: '', preco: 0, imagem: imagem.text.trim())),
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: salvando ? null : salvar,
              icon: const Icon(Icons.save_outlined),
              label: Text(salvando ? 'Salvando...' : gravado ? 'Atualizar catálogo' : 'Salvar produto')),
          ])),
        ),
      )),
    ),
  );
}
