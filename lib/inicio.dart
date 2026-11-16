import 'package:flutter/material.dart';
import 'produtos.dart';
import 'carrinho.dart';
import 'contato.dart';
import 'login.dart';
import 'api.dart';
import 'admin.dart';
import 'perfil.dart';
import 'design.dart';
import 'produto_model.dart';
import 'detalhes.dart';

class InicioPage extends StatefulWidget {
  const InicioPage({super.key});
  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  int pagina = 0;

  Future<void> sair() async {
    final confirmar = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text('Seu carrinho continuará salvo para o próximo acesso.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sair')),
        ],
      ));
    if (confirmar != true || !mounted) return;
    final carrinho = CarrinhoDados.instancia;
    if (!await carrinho.aguardarSalvamento() || !mounted) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('O carrinho não foi salvo. Abra o carrinho e tente novamente.')));
      return;
    }
    try {
      await Api.sair();
    } catch (erro) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$erro')));
      return;
    }
    if (!mounted) return;
    carrinho.desconectar();
    Navigator.pushAndRemoveUntil(context,
      MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final nomes = ['Início', 'Produtos', 'Carrinho', 'Contato',
      if (!Api.visitante) 'Meu perfil', if (Api.administrador) 'Administração'];
    final icones = <Widget>[const Icon(Icons.grid_view_outlined), const Icon(Icons.shopping_bag_outlined),
      const CarrinhoIcone(), const Icon(Icons.chat_bubble_outline),
      if (!Api.visitante) const Icon(Icons.person_outline),
      if (Api.administrador) const Icon(Icons.admin_panel_settings_outlined)];
    final paginas = IndexedStack(index: pagina, children: [
      HomeAutoPrime(onProdutos: () => setState(() => pagina = 1),
        onContato: () => setState(() => pagina = 3), onSair: sair),
      const ProdutosPage(), const CarrinhoPage(), const ContatoPage(),
      if (!Api.visitante) PerfilPage(onSair: sair), if (Api.administrador) const AdminPage()]);
    final desktop = MediaQuery.sizeOf(context).width >= 1050;
    return Scaffold(
      body: desktop ? Row(children: [
        Container(width: 238, decoration: const BoxDecoration(color: Colors.white,
          border: Border(right: BorderSide(color: primeLine))),
          child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.fromLTRB(22, 28, 16, 32), child: PrimeBrand()),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text('NAVEGAÇÃO',
              style: TextStyle(color: primeMuted, fontSize: 10, letterSpacing: 1.8, fontWeight: FontWeight.w700))),
            const SizedBox(height: 14),
            Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 14), children: [
              for (var i = 0; i < nomes.length; i++) Padding(padding: const EdgeInsets.only(bottom: 8),
                child: Material(color: pagina == i ? const Color(0xffffeded) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12), child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    selected: pagina == i, selectedColor: primeRed, iconColor: primeMuted,
                    leading: icones[i], title: Text(nomes[i], style: TextStyle(fontSize: 14,
                      fontWeight: pagina == i ? FontWeight.w700 : FontWeight.w500)),
                    onTap: () => setState(() => pagina = i))))])),
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Text(Api.visitante ? 'Você está como visitante' : Api.administrador ? 'Conta de administrador' : 'Sua conta AutoPrime',
                style: const TextStyle(fontSize: 12, color: primeMuted)),
                const SizedBox(height: 8), OutlinedButton.icon(onPressed: sair,
                  icon: const Icon(Icons.logout, size: 18), label: Text(Api.visitante ? 'Entrar / criar conta' : 'Sair da conta'))])),
          ]))), Expanded(child: paginas)]) : paginas,
      bottomNavigationBar: desktop ? null : NavigationBar(selectedIndex: pagina,
        labelBehavior: nomes.length > 5 || MediaQuery.sizeOf(context).width < 400
          ? NavigationDestinationLabelBehavior.onlyShowSelected : NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (v) => setState(() => pagina = v),
        destinations: [for (var i = 0; i < nomes.length; i++) NavigationDestination(icon: icones[i],
          label: nomes[i] == 'Administração' ? 'Admin' : nomes[i] == 'Meu perfil' ? 'Perfil' : nomes[i])]),
    );
  }
}

class HomeAutoPrime extends StatelessWidget {
  final VoidCallback onProdutos, onContato, onSair;
  const HomeAutoPrime({super.key, required this.onProdutos, required this.onContato, required this.onSair});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const PrimeBrand(), actions: [IconButton(
      tooltip: Api.visitante ? 'Entrar ou criar conta' : 'Sair da conta', onPressed: onSair,
      icon: const Icon(Icons.logout)), const SizedBox(width: 12)]),
    body: ListenableBuilder(listenable: CatalogoDados.instancia, builder: (context, _) =>
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1240),
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Container(padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: primeInk, borderRadius: BorderRadius.circular(24)),
            child: LayoutBuilder(builder: (context, constraints) {
              final largo = constraints.maxWidth >= 700;
              final texto = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('PEÇAS & ACESSÓRIOS', style: TextStyle(color: Color(0xffff9494),
                  fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                Text('Mais cuidado.\nMais AutoPrime.', style: TextStyle(color: Colors.white,
                  fontSize: largo ? 46 : 34, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -1.4)),
                const SizedBox(height: 18),
                const Text('Encontre peças e acessórios para o seu carro,\ncom tudo organizado em um só lugar.',
                  style: TextStyle(color: Color(0xffc5cedc), height: 1.7, fontSize: 15)),
                const SizedBox(height: 24),
                ElevatedButton.icon(onPressed: onProdutos, icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Explorar produtos')),
              ]);
              final foto = catalogo.isEmpty ? const SizedBox.shrink() : PrimeCard(
                child: Padding(padding: const EdgeInsets.all(18), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    ProdutoVisual(produto: catalogo.first, altura: 180), const SizedBox(height: 12),
                    Text(catalogo.first.nome, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                    const SizedBox(height: 6), Text(dinheiro(catalogo.first.preco),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
                    TextButton(onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => DetalhesPage(produto: catalogo.first))),
                      child: const Text('Conhecer produto'))])));
              return largo ? Row(children: [Expanded(flex: 5, child: texto), const SizedBox(width: 28),
                if (catalogo.isNotEmpty) Expanded(flex: 3, child: foto)]) : texto;
            })),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, constraints) {
            final cards = [
              _Ajuda('Encontre com facilidade', 'Busque pelo nome ou categoria.', Icons.search, onProdutos),
              _Ajuda('Escolha no seu ritmo', 'Veja fotos, preços e detalhes.', Icons.shopping_bag_outlined, onProdutos),
              _Ajuda('Fale com a equipe', 'Tire suas dúvidas pelo WhatsApp.', Icons.chat_bubble_outline, onContato)];
            return constraints.maxWidth >= 780 ? Row(children: [for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 16), Expanded(child: cards[i])]])
              : Column(children: [for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 8), child: card)]);
          }),
          const SizedBox(height: 30),
          Wrap(alignment: WrapAlignment.spaceBetween, spacing: 20, runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center, children: [
              const Text('Explore o catálogo', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
              TextButton.icon(onPressed: onProdutos, icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Ver todos os produtos'))]),
          const SizedBox(height: 18),
          if (catalogo.isEmpty) const PrimeCard(child: Padding(padding: EdgeInsets.all(24),
            child: Text('Os produtos aparecerão aqui assim que forem cadastrados.')))
          else LayoutBuilder(builder: (context, constraints) => GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: catalogo.take(4).length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth >= 1100 ? 4 : constraints.maxWidth >= 820 ? 3 : constraints.maxWidth >= 540 ? 2 : 1,
              mainAxisExtent: 500 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 16, mainAxisSpacing: 20, crossAxisSpacing: 20),
            itemBuilder: (context, i) => ProdutoCard(produto: catalogo[i]))),
          const SizedBox(height: 28),
          const Divider(), const SizedBox(height: 12),
          const Text('AutoPrime · Peças e acessórios automotivos', textAlign: TextAlign.center,
            style: TextStyle(color: primeMuted, fontSize: 12)), const SizedBox(height: 12),
        ])))));
}

class _Ajuda extends StatelessWidget {
  final String titulo, texto;
  final IconData icone;
  final VoidCallback onTap;
  const _Ajuda(this.titulo, this.texto, this.icone, this.onTap);
  @override
  Widget build(BuildContext context) => PrimeCard(child: InkWell(onTap: onTap,
    borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.all(20),
      child: Row(children: [Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xffffeded), borderRadius: BorderRadius.circular(12)),
        child: Icon(icone, color: primeRed, size: 22)), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 4), Text(texto, style: const TextStyle(color: primeMuted, fontSize: 12))]))]))));
}
