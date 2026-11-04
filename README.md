# Rota Condomínio: como colocar no ar

Os arquivos principais:

| Arquivo | Para que serve |
|---|---|
| `supabase/setup.sql` | Cria o banco (tabelas, segurança e as funções do código). Rode uma vez. |
| `supabase/vendas.sql` | Acrescenta o mapa de vendas ao banco. Rode depois do `setup.sql`. |
| `config.js` | Onde você cola a URL e a chave do Supabase. |
| `index.html` | Painel: login, mapeamento, tela da portaria, QR do totem e mapa de vendas. |
| `entregador.html` | Página que o entregador abre ao escanear o QR do totem. |
| `vendas.html` | Mapa de vendas público: corretor e cliente veem os lotes e o caminho até eles. |
| `rotas.js` | Calcula o caminho pelas ruas internas (usado pelas páginas). |

## Parte 1: Supabase (uns 10 minutos)

1. Em supabase.com, crie um projeto novo (ex.: `rota-condominio`), região **South America (São Paulo)**.
2. No menu lateral, abra **SQL Editor**, clique em **New query**, cole todo o conteúdo de `supabase/setup.sql` e clique em **Run**. Deve aparecer "Success". Depois, numa nova query, faça o mesmo com `supabase/vendas.sql`.
3. Para criar o seu login, vá em **Authentication > Users > Add user > Create new user**. Informe e-mail e senha e marque **Auto Confirm User**.
4. Para fechar o cadastro público, vá em **Authentication > Sign In / Providers** (ou **Settings**) e desligue **Allow new users to sign up**. Assim só entra quem você criar.
5. Clique em **Connect** no topo do projeto (ou vá em **Project Settings > API**) e copie:
   - a **Project URL** (`https://xxxx.supabase.co`);
   - a chave **anon** ou **publishable**. **Nunca** use a `service_role`/`secret`.
6. Abra `config.js` num editor de texto (pode ser o Bloco de Notas), cole os dois valores e salve.

## Parte 2: GitHub Pages (uns 5 minutos)

1. No GitHub, clique em **New repository**, dê o nome `rota-condominio`, deixe **Public** e crie.
2. Clique em **uploading an existing file**, arraste os 4 arquivos (`index.html`, `entregador.html`, `config.js` e este LEIA-ME) e clique em **Commit changes**.
3. Vá em **Settings > Pages**. Em *Source*, escolha **Deploy from a branch**, branch **main**, pasta **/ (root)**, e clique em **Save**.
4. Em 1 ou 2 minutos, o site fica no ar em `https://SEU-USUARIO.github.io/rota-condominio/`.

> O site é publicado pela Vercel a partir deste repositório privado.

## Parte 3: Primeiro uso

1. Abra o link do site e entre com o e-mail e a senha que você criou.
2. Clique em **+ Condomínio** e dê um nome.
3. Na aba **Mapear**, busque o bairro e siga o **Passo a passo** da barra lateral: portaria, ruas e lotes. Para trazer as casas de teste, use **Importar JSON (versão antiga)** com o arquivo que você exportou da primeira versão.
4. Na aba **QR do totem**, clique em **Imprimir placa**. Esse QR fica fixo na portaria.
5. Na aba **Portaria**, escolha a casa e clique em **Gerar código**. Escaneie a placa com o celular, digite o código e a rota deve abrir.

## Mapa de vendas (esboço)

Serve para mostrar a corretores e clientes os lotes à venda e o caminho até cada um. Depois que as vendas acabam, o mesmo mapa continua servindo à portaria e aos entregadores.

1. **Banco:** no Supabase, abra **SQL Editor > New query**, cole todo o conteúdo de `supabase/vendas.sql` e clique em **Run**. Rodar de novo não causa problema.
2. **Ligar o modo vendas:** no painel, escolha o condomínio, abra a aba **Vendas** e marque **Modo vendas (mapa público)**. Desligado, o link mostra só um aviso de mapa indisponível.
3. **Marcar o stand:** na aba **Mapear**, no passo **Stand**, clique em **Marcar** e depois no ponto do stand de vendas. As rotas saem dele; sem stand, saem da portaria. Para conferir, use **Testar do stand** no popup de um lote.
4. **Preencher os lotes:** clique em cada lote, depois em **Editar**, e escolha a **Situação** (disponível, reservado ou vendido). Preencha também **Área** e **Preço** (ex.: 250.000,00). Os pinos mudam de cor: verde, amarelo e cinza.
5. **Compartilhar:** na aba **Vendas**, use **Copiar link** para mandar aos corretores (pelo WhatsApp, por exemplo) ou **Imprimir** para colocar o QR no stand. O link é `vendas.html?c=<código do condomínio>`.

O mapa público mostra os lotes coloridos pela situação, a área, o preço (ou "Consulte", se estiver vazio) e o caminho pelas ruas internas até os lotes disponíveis e reservados. Ele nunca mostra as observações dos lotes nem o preço dos vendidos. Quando as vendas acabarem, desligue o modo vendas. A portaria e os entregadores continuam funcionando igual.

## Como funciona a segurança

- As tabelas só podem ser lidas e alteradas por quem fez login (você e os porteiros).
- O entregador não vê lista nenhuma. Ele só recebe o destino se digitar um código válido daquele condomínio.
- Cada código vale 20 minutos. Para mudar o tempo, troque `interval '20 minutes'` no SQL.
- A chave anon/publishable fica visível no site, e isso é normal: quem protege os dados são as regras do banco.

## Limitações desta versão (MVP)

- Todos os logins veem todos os condomínios. Isso basta enquanto o único usuário for você. Para ter porteiros de vários condomínios, falta separar o acesso por condomínio.
- Não há limite de tentativas no código de 4 dígitos. Para o piloto é aceitável, mas para produção vale aumentar para 5 ou 6 dígitos ou limitar as tentativas.
- Os mapas de satélite (Esri) e de ruas (CARTO) estão no modo gratuito, que serve para o piloto. Quando houver clientes pagantes, vale contratar um plano (MapTiler, por exemplo).
