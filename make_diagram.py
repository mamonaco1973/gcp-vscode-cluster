"""Generate gcp-vscode-cluster.drawio in the project's Lucid-style diagram look.

Ports the AWS counterpart's visual language -- dashed cloud boundary, rounded
white cards with a Lucide glyph and two detail lines, coloured edges carrying
the protocol -- onto this build's topology.

Deliberately narrower than the repo. The Windows admin host and the Samba
gateway are real but they are not on the path a user takes to an editor, so
they appear once as a muted footnote instead of as cards competing with the
managed instance group.

Icons are harvested from the AWS diagram rather than re-encoded here: they are
Lucide SVGs embedded as data URIs, and the stroke colour is baked into the URI,
so recolouring means rewriting the %23rrggbb escape.

Run:  python make_diagram.py  &&  drawio -x -f png -o gcp-vscode-cluster.png ...
"""
import io
import os
import re

AWS_DRAWIO = r"C:\cloudenv\aws-vscode-cluster\aws-vscode-cluster.drawio"
OUT = "gcp-vscode-cluster.drawio"

# ==============================================================================
# Palette -- shared with the AWS diagram so the two read as a series
# ==============================================================================

NAVY = "#1A2B4A"  # structure: boundaries, primary text
BLUE = "#336791"  # front door: load balancer
RED = "#C0392B"   # subnet boundary
GREEN = "#2E7D4F" # identity: domain controller
TEAL = "#1F8A70"  # storage: Filestore
AMBER = "#B9770E" # build artefact: the Packer image
PURPLE = "#7A5CA6" # the per-node detail inset
MUTED = "#5B6B82"  # secondary text


# ==============================================================================
# Icon harvesting
# ==============================================================================

def load_icons():
    """Pull the Lucide data-URI image styles out of the AWS diagram.

    Returns:
        Mapping of AWS cell id (e.g. "c_alb_i") to its full mxCell style string.
    """
    src = io.open(AWS_DRAWIO, encoding="utf-8").read()
    out = {}
    for m in re.finditer(r'<mxCell id="([^"]+_i)" value="" style="(shape=image[^"]*)"', src):
        out[m.group(1)] = m.group(2)
    return out


def recolour(style, colour):
    """Swap the stroke colour baked into a Lucide data URI.

    Args:
        style: An mxCell image style harvested by load_icons().
        colour: Target colour as "#rrggbb".

    Returns:
        The style with its single %23rrggbb escape replaced.
    """
    return re.sub(r"%23[0-9A-Fa-f]{6}", "%23" + colour.lstrip("#"), style)


ICONS = load_icons()

# AWS cell id -> what it depicts here. The mapping is 1:1 because the two
# builds are the same architecture on different clouds.
GLYPH = {
    "browser": "c_br_i",
    "lb":      "c_alb_i",
    "mig":     "c_asg_i",
    "ad":      "c_ad_i",
    "store":   "c_efs_i",
    "image":   "c_ami_i",
    "broker":  "c_brk_i",
    "code":    "c_cs_i",
    "cloud":   "region_i",
    "vpc":     "vpc_i",
}


# ==============================================================================
# XML emitters
# ==============================================================================

cells = []


def esc(t):
    return (t.replace("&", "&amp;").replace("<", "&lt;")
             .replace(">", "&gt;").replace('"', "&quot;"))


def raw(cid, value, style, x, y, w, h):
    cells.append(
        '        <mxCell id="%s" value="%s" style="%s" vertex="1" parent="1">'
        '<mxGeometry x="%d" y="%d" width="%d" height="%d" as="geometry"/></mxCell>'
        % (cid, value, style, x, y, w, h))


def container(cid, label, colour, x, y, w, h, fill="none", fontsize=20,
              dashed=False, indent=58):
    style = ("rounded=0;whiteSpace=wrap;html=1;fillColor=%s;strokeColor=%s;"
             "strokeWidth=%s;fontColor=%s;align=left;verticalAlign=top;"
             "spacingTop=12;spacingLeft=%d;fontStyle=1;fontSize=%d;"
             % (fill, colour, "2.5" if dashed else "2", colour, indent, fontsize))
    if dashed:
        style += "dashed=1;dashPattern=8 6;"
    raw(cid, esc(label), style, x, y, w, h)


def badge(cid, glyph, colour, x, y, size=34):
    raw(cid, "", recolour(ICONS[GLYPH[glyph]], colour), x, y, size, size)


def card(cid, glyph, colour, title, lines, x, y, w, h, tail=None):
    """A rounded white card: glyph on the left, title and detail lines right."""
    raw(cid, "", "rounded=1;whiteSpace=wrap;html=1;fillColor=#FFFFFF;"
                 "strokeColor=%s;strokeWidth=2;" % colour, x, y, w, h)
    badge(cid + "_i", glyph, colour, x + 26, y + (h - 52) // 2, 52)

    head = '&lt;b style=&quot;font-size:22px&quot;&gt;%s&lt;/b&gt;' % esc(title)
    if tail:
        head += ('&lt;span style=&quot;font-size:16px;color:%s&quot;&gt;&amp;nbsp;'
                 '%s&lt;/span&gt;' % (colour, esc(tail)))
    body = "".join(
        '&lt;br&gt;&lt;span style=&quot;font-size:15px;color:%s&quot;&gt;%s'
        '&lt;/span&gt;' % (MUTED, esc(l)) for l in lines)

    raw(cid + "_t", head + body,
        "text;html=1;align=left;verticalAlign=middle;fillColor=none;"
        "strokeColor=none;fontColor=%s;" % NAVY,
        x + 92, y + 10, w - 112, h - 20)


def edge(cid, src, dst, label, colour, exit_xy, entry_xy, dashed=False,
         dotted=False, width="2.5", fontsize=16):
    style = ("edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;strokeColor=%s;"
             "strokeWidth=%s;fontColor=%s;fontSize=%d;fontStyle=1;"
             "exitX=%s;exitY=%s;exitDx=0;exitDy=0;entryX=%s;entryY=%s;"
             "entryDx=0;entryDy=0;labelBackgroundColor=#FFFFFF;"
             % (colour, width, colour, fontsize,
                exit_xy[0], exit_xy[1], entry_xy[0], entry_xy[1]))
    style += "endArrow=none;" if dotted else "endArrow=classic;"
    if dashed:
        style += "dashed=1;dashPattern=8 6;"
    if dotted:
        style += "dashed=1;dashPattern=1 4;"
    cells.append(
        '        <mxCell id="%s" value="%s" style="%s" edge="1" parent="1" '
        'source="%s" target="%s"><mxGeometry relative="1" as="geometry"/></mxCell>'
        % (cid, esc(label), style, src, dst))


# ==============================================================================
# Layout
# ==============================================================================

raw("frame", "", "rounded=0;fillColor=#FFFFFF;strokeColor=none;", 0, 0, 1920, 1080)

container("region", "Google Cloud  \u2014  us-central1", NAVY,
          340, 60, 1540, 985, dashed=True, fontsize=24)
badge("region_i", "cloud", NAVY, 356, 74)

container("vpc", "VPC  \u2014  vscode-vpc", NAVY, 380, 140, 1470, 870,
          fill="#F8FAFC", fontsize=20)
badge("vpc_i", "vpc", NAVY, 396, 154)

# --- browser, outside the cloud boundary -------------------------------------
card("c_br", "browser", NAVY, "Browser",
     ["one session per user"], 40, 292, 280, 120)

# --- the front door. Global, so it sits in the VPC but outside the subnet:
#     a GCP external LB is not subnet-scoped the way an ALB is. -------------
card("c_lb", "lb", BLUE, "Global HTTPS Load Balancer",
     ["443 \u00b7 self-signed cert with an IP SAN",
      "cookie affinity \u00b7 /healthz \u00b7 80 redirects to 443"],
     430, 210, 520, 130)

# --- the subnet holds the things that actually have addresses ---------------
container("sn", "vscode-subnet", RED, 410, 400, 560, 470,
          fill="#FDF2F0", fontsize=16, indent=20)

card("c_mig", "mig", RED, "VS Code Cluster",
     ["Regional MIG \u00b7 e2-standard-2 \u00b7 2 \u2192 4",
      "domain-joined at boot",
      "scale-up only \u2014 no scale-in"],
     430, 450, 520, 150)

card("c_ad", "ad", GREEN, "Mini-AD Domain Controller",
     ["Ubuntu \u00b7 Samba 4 \u00b7 DNS + Kerberos",
      "vscode-users gates every sign-in"],
     430, 700, 520, 140)

# Present but off the path to an editor, so stated once and left alone.
raw("aside",
    '&lt;span style=&quot;font-size:15px;color:%s&quot;&gt;'
    'Also in the VPC: a Windows admin host for ADUC, and a gateway '
    're-exporting the share over SMB.&lt;/span&gt;' % MUTED,
    "text;html=1;whiteSpace=wrap;align=left;verticalAlign=top;fillColor=none;"
    "strokeColor=none;",
    412, 890, 540, 70)

# --- right column ------------------------------------------------------------
card("c_img", "image", AMBER, "vscode-image", [
    "code-server (MIT) + session broker baked in",
    "/etc/pam.d/vscode wired to SSSD \u00b7 Open VSX pinned"],
    1010, 210, 800, 130, tail="(Packer)")

card("c_fs", "store", TEAL, "Cloud Filestore", [
    "mounted at /home \u2014 files follow the user to any node",
    "/nfs/extensions stages VSIX packages cluster-wide"],
    1010, 420, 800, 130)

container("detail", "Inside each cluster node", PURPLE,
          1010, 620, 800, 330, fontsize=18, indent=20)

card("c_brk", "broker", PURPLE, "session broker", [
    "PAM auth, then systemd-run --uid as the real Linux user",
    "reverse-proxies HTTP and the editor's WebSocket"],
    1040, 670, 740, 110)

card("c_cs", "code", PURPLE, "code-server", [
    "one private process per user, --auth none on 127.0.0.1",
    "editor state node-local at /var/lib/vscode/$USER"],
    1040, 820, 740, 110)

# --- edges -------------------------------------------------------------------
edge("e_https", "c_br", "c_lb", "HTTPS 443", NAVY, ("1", "0.5"), ("0", "0.5"))
edge("e_8080", "c_lb", "c_mig", "8080 \u00b7 sticky", NAVY,
     ("0.5", "1"), ("0.5", "0"))
edge("e_auth", "c_mig", "c_ad", "PAM / SSSD \u00b7 Kerberos", GREEN,
     ("0.5", "1"), ("0.5", "0"), dashed=True)
edge("e_nfs", "c_mig", "c_fs", "NFS", TEAL, ("1", "0.72"), ("0", "0.5"))
edge("e_boot", "c_img", "c_mig", "instances boot from", AMBER,
     ("0", "0.5"), ("1", "0.18"), dashed=True, width="2")
edge("e_spawn", "c_brk", "c_cs", "spawns \u00b7 loopback", PURPLE,
     ("0.5", "1"), ("0.5", "0"), width="2")
edge("e_zoom", "c_mig", "detail", "", MUTED,
     ("1", "0.85"), ("0", "0.1"), dotted=True, width="2")


# ==============================================================================
# Emit
# ==============================================================================

doc = ('<mxfile host="app.diagrams.net">\n'
       '  <diagram name="Architecture" id="gcp-vscode-cluster">\n'
       '    <mxGraphModel dx="1600" dy="1000" grid="0" gridSize="10" guides="1" '
       'tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" '
       'pageWidth="1920" pageHeight="1080" math="0" shadow="0">\n'
       '      <root>\n'
       '        <mxCell id="0"/>\n'
       '        <mxCell id="1" parent="0"/>\n'
       + "\n".join(cells) +
       '\n      </root>\n'
       '    </mxGraphModel>\n'
       '  </diagram>\n'
       '</mxfile>\n')

io.open(OUT, "w", encoding="utf-8", newline="\n").write(doc)
print("wrote %s (%d cells)" % (OUT, len(cells)))
