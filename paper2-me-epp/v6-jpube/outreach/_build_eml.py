"""
Gera dois .eml (Firpo e Soares) prontos para abrir no Outlook como rascunho.
- Anexa paper_v5.pdf e online_appendix.pdf por padrão.
- Campo `To` deixado como placeholder — preencher antes de enviar.
"""

from email.message import EmailMessage
from pathlib import Path
import mimetypes

ROOT = Path(__file__).resolve().parent
MS = ROOT.parent / "manuscript"
ATTACH = [MS / "paper_v5.pdf", MS / "online_appendix.pdf"]

FROM = "Darcio Genicolo-Martins <darcio.g.martins@gmail.com>"

EMAILS = [
    {
        "filename": "email_firpo.eml",
        "to": "Sergio Firpo <PREENCHER_EMAIL@insper.edu.br>",
        "subject": "Pedido de leitura presubmission — paper sobre set-asides de PME no JPubE",
        "body": """Sergio,

Boa tarde. Estou prestes a submeter ao Journal of Public Economics um paper solo que terminei de calibrar nas últimas semanas, e gostaria de pedir 30 minutos do seu tempo para um par de comentários antes da submissão — se couber na sua agenda nas próximas duas a três semanas.

O paper usa a reversão da exceção do Grupo 65 na BEC-SP em março de 2018 como gatilho legal limpo para identificar o efeito da regra de exclusividade para ME/EPP em pregões eletrônicos. Combina a decomposição within-auction de Krasnokutskaya (2011) com um contrafactual de entrada endógena à la Athey-Coey-Levin (2013) e fecha com um cálculo de bem-estar no esquema de pesos de Saez-Stantcheva (2016). O resultado central é que ignorar a margem de entrada subestima o custo fiscal realizado em ~50-60%, e que a preferência de 10% domina o set-aside em mercados espessos mas não em mercados finos.

O que eu queria mais era a sua leitura crítica de duas coisas específicas: (i) o framing da contribuição na introdução vis-à-vis a literatura de set-asides (Athey-Levin-Seira, Marion, Nakabayashi), e (ii) se a decomposição entre componente within-auction e margem de participação está clara o suficiente para um leitor de public economics que não vem de IO estrutural. Não preciso de revisão técnica linha a linha — só do filtro de quem já passou por esse pipeline editorial várias vezes.

Anexei o PDF da v5 (45 páginas) e o apêndice online. Posso passar na sua sala em qualquer horário, ou a gente conversa por vídeo se for mais fácil.

Obrigado, e um abraço,
Darcio
""",
    },
    {
        "filename": "email_soares.eml",
        "to": "Rodrigo Soares <PREENCHER_EMAIL@insper.edu.br>",
        "subject": "Pedido de leitura presubmission — paper para o JPubE, e talvez uma intro",
        "body": """Rodrigo,

Tudo bem? Estou prestes a submeter ao Journal of Public Economics um paper solo que terminei de calibrar. Antes de mandar, queria te pedir duas coisas — em ordem de importância.

A primeira é a sua leitura crítica. O paper usa a reversão da exceção do Grupo 65 na BEC-SP em março de 2018 como gatilho legal limpo para identificar o efeito da regra de exclusividade para ME/EPP em pregões eletrônicos, decompõe o efeito entre a margem within-auction (Krasnokutskaya 2011) e a margem de participação endógena (Athey-Coey-Levin 2013), e fecha com cálculo de bem-estar no esquema Saez-Stantcheva. O resultado central é que ignorar a margem de entrada subestima o custo fiscal realizado em ~50-60%, e que a preferência de 10% domina o set-aside em mercados espessos mas não em finos. Não preciso de revisão linha a linha — só de 30 minutos do seu filtro sobre se a contribuição está bem posicionada para a literatura de public economics e se a identificação convence num primeiro round de leitura.

A segunda — e essa só faz sentido se a primeira passar no seu filtro — é se você acharia razoável me apresentar ao Francesco Decarolis. Ele é o leitor Tier 2 mais natural para esse paper (procurement aplicado, mercados públicos europeus, recepção a working papers fora do circuito anglo), e você foi o caminho óbvio que me ocorreu. Se achar que ainda não está pronto, ou que faz mais sentido apresentar primeiro num seminário aqui, prefiro essa orientação à intro prematura.

Anexei o PDF da v5 (45 páginas) e o apêndice online. Posso passar na sua sala em qualquer momento da semana, ou a gente conversa por vídeo se for mais fácil.

Obrigado, e um abraço,
Darcio
""",
    },
]


def attach_files(msg: EmailMessage, files: list[Path]) -> None:
    for path in files:
        if not path.is_file():
            print(f"  aviso: anexo não encontrado: {path}")
            continue
        ctype, encoding = mimetypes.guess_type(str(path))
        if ctype is None or encoding is not None:
            ctype = "application/octet-stream"
        maintype, subtype = ctype.split("/", 1)
        with path.open("rb") as fh:
            data = fh.read()
        msg.add_attachment(
            data, maintype=maintype, subtype=subtype, filename=path.name
        )


def build_eml(spec: dict) -> EmailMessage:
    msg = EmailMessage()
    msg["From"] = FROM
    msg["To"] = spec["to"]
    msg["Subject"] = spec["subject"]
    msg.set_content(spec["body"])
    attach_files(msg, ATTACH)
    return msg


for spec in EMAILS:
    out_path = ROOT / spec["filename"]
    msg = build_eml(spec)
    out_path.write_bytes(bytes(msg))
    size_kb = out_path.stat().st_size / 1024
    print(f"escrito: {out_path}  ({size_kb:,.0f} KB)")
