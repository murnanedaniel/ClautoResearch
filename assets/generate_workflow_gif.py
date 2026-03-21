"""Generate an animated workflow GIF for ClautoResearch README."""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch
from PIL import Image
import io
import os

# --- Config ---
W, H = 12, 6.5
DPI = 150
BG = '#0d1117'
FG = '#c9d1d9'
ACCENT = '#58a6ff'
GREEN = '#3fb950'
ORANGE = '#d29922'
PURPLE = '#bc8cff'
RED = '#f85149'
DIMMED = '#484f58'
BOX_BG = '#161b22'
BOX_BORDER = '#30363d'

# Cycle layout
PHASES = [
    {'name': 'Planning\nMeeting', 'color': PURPLE, 'icon': 'PLAN', 'x': 0.5, 'tag': 'onboard'},
    {'name': 'Deep Lit\nReview', 'color': ACCENT, 'icon': 'LIT', 'x': 1.7, 'tag': 'onboard'},
    {'name': 'Mon\nCheck-in', 'color': GREEN, 'icon': 'SLIDES', 'x': 3.1, 'tag': 'gate'},
    {'name': 'Explore &\nDesign', 'color': ACCENT, 'icon': 'R&D', 'x': 4.5, 'tag': 'work'},
    {'name': 'Wed\nCheck-in', 'color': GREEN, 'icon': 'SLIDES', 'x': 5.9, 'tag': 'gate'},
    {'name': 'Build &\nRun', 'color': ORANGE, 'icon': 'CODE', 'x': 7.3, 'tag': 'work'},
    {'name': 'Mon\nCheck-in', 'color': GREEN, 'icon': 'SLIDES', 'x': 8.7, 'tag': 'gate'},
]

def draw_base(fig, ax):
    """Draw the static workflow elements."""
    ax.set_xlim(-0.3, 10.5)
    ax.set_ylim(-1.5, 5.5)
    ax.set_facecolor(BG)
    fig.set_facecolor(BG)
    ax.axis('off')

    # Title
    ax.text(5.1, 5.0, 'ClautoResearch Workflow', fontsize=20, fontweight='bold',
            color=FG, ha='center', va='center', fontfamily='monospace')

    # Phase boxes
    box_y = 2.8
    box_w = 1.0
    box_h = 1.2
    for i, p in enumerate(PHASES):
        x = p['x']
        rect = FancyBboxPatch((x - box_w/2, box_y - box_h/2),
                              box_w, box_h,
                              boxstyle="round,pad=0.08",
                              facecolor=BOX_BG, edgecolor=BOX_BORDER, linewidth=1.5)
        ax.add_patch(rect)
        ax.text(x, box_y + 0.15, p['name'], fontsize=8, color=FG,
                ha='center', va='center', fontfamily='sans-serif', fontweight='bold')
        ax.text(x, box_y - 0.4, p['icon'], fontsize=7, ha='center', va='center',
                color=p['color'], fontfamily='monospace', fontweight='bold', alpha=0.7)

    # Arrows between phases
    for i in range(len(PHASES) - 1):
        x1 = PHASES[i]['x'] + box_w/2 + 0.02
        x2 = PHASES[i+1]['x'] - box_w/2 - 0.02
        ax.annotate('', xy=(x2, box_y), xytext=(x1, box_y),
                    arrowprops=dict(arrowstyle='->', color=DIMMED, lw=1.5))

    # Cycle loop arrow (from last Mon check-in back to Explore)
    ax.annotate('', xy=(PHASES[3]['x'], box_y - box_h/2 - 0.15),
                xytext=(PHASES[6]['x'], box_y - box_h/2 - 0.15),
                arrowprops=dict(arrowstyle='->', color=DIMMED, lw=1.5,
                               connectionstyle='arc3,rad=0.3'))
    ax.text(6.1, 1.15, 'next cycle', fontsize=7, color=DIMMED,
            ha='center', va='center', fontstyle='italic')

    # Onboarding bracket
    ax.plot([PHASES[0]['x'] - 0.5, PHASES[0]['x'] - 0.5], [box_y - 0.7, box_y + 0.7],
            color=PURPLE, lw=1.5, alpha=0.5)
    ax.plot([PHASES[0]['x'] - 0.5, PHASES[1]['x'] + 0.6], [box_y + 0.7, box_y + 0.7],
            color=PURPLE, lw=1.5, alpha=0.5)
    ax.plot([PHASES[1]['x'] + 0.6, PHASES[1]['x'] + 0.6], [box_y + 0.7, box_y - 0.7],
            color=PURPLE, lw=1.5, alpha=0.5)
    ax.text(1.1, box_y + 0.95, 'onboarding (once)', fontsize=7, color=PURPLE,
            ha='center', va='center', fontstyle='italic', alpha=0.7)

    # Legend
    legend_y = -0.8
    items = [
        (ACCENT, '● Autonomous work'),
        (GREEN, '● Supervisor gate (slides)'),
        (ORANGE, '● Execution'),
        (PURPLE, '● Interactive meeting'),
    ]
    for i, (c, label) in enumerate(items):
        ax.text(1.5 + i * 2.5, legend_y, label, fontsize=8, color=c,
                ha='center', va='center', fontfamily='sans-serif')

    # Direction/Velocity meters
    ax.text(10.0, 4.2, 'Direction', fontsize=8, color=FG, ha='center',
            fontfamily='sans-serif', fontweight='bold')
    ax.text(10.0, 3.2, 'Velocity', fontsize=8, color=FG, ha='center',
            fontfamily='sans-serif', fontweight='bold')

    return box_y, box_w, box_h


def draw_meter(ax, x, y, value, color):
    """Draw a small horizontal meter bar."""
    bar_w = 0.8
    bar_h = 0.15
    # Background
    bg = FancyBboxPatch((x - bar_w/2, y - bar_h/2), bar_w, bar_h,
                        boxstyle="round,pad=0.02", facecolor=BOX_BORDER, edgecolor='none')
    ax.add_patch(bg)
    # Fill
    fill_w = bar_w * (value / 100)
    if fill_w > 0.01:
        fill = FancyBboxPatch((x - bar_w/2, y - bar_h/2), fill_w, bar_h,
                              boxstyle="round,pad=0.02", facecolor=color, edgecolor='none', alpha=0.8)
        ax.add_patch(fill)
    ax.text(x + bar_w/2 + 0.15, y, f'{value}%', fontsize=7, color=FG,
            ha='left', va='center')


def make_frame(step_idx, direction, velocity, description, detail):
    """Generate a single frame."""
    fig, ax = plt.subplots(figsize=(W, H))
    box_y, box_w, box_h = draw_base(fig, ax)

    # Highlight active phase
    for i, p in enumerate(PHASES):
        if i == step_idx:
            highlight = FancyBboxPatch(
                (p['x'] - box_w/2 - 0.04, box_y - box_h/2 - 0.04),
                box_w + 0.08, box_h + 0.08,
                boxstyle="round,pad=0.08",
                facecolor='none', edgecolor=p['color'], linewidth=2.5, alpha=0.9)
            ax.add_patch(highlight)
            # Glow effect
            glow = FancyBboxPatch(
                (p['x'] - box_w/2 - 0.08, box_y - box_h/2 - 0.08),
                box_w + 0.16, box_h + 0.16,
                boxstyle="round,pad=0.1",
                facecolor='none', edgecolor=p['color'], linewidth=1, alpha=0.3)
            ax.add_patch(glow)

    # Direction/Velocity meters
    draw_meter(ax, 10.0, 3.85, direction, ACCENT)
    draw_meter(ax, 10.0, 2.85, velocity, ORANGE)

    # Description panel
    desc_y = 0.3
    desc_rect = FancyBboxPatch((1.5, desc_y - 0.35), 7.2, 0.7,
                               boxstyle="round,pad=0.1",
                               facecolor=BOX_BG, edgecolor=BOX_BORDER, linewidth=1)
    ax.add_patch(desc_rect)
    ax.text(5.1, desc_y + 0.1, description, fontsize=10, color=FG,
            ha='center', va='center', fontweight='bold', fontfamily='sans-serif')
    ax.text(5.1, desc_y - 0.15, detail, fontsize=8, color=DIMMED,
            ha='center', va='center', fontfamily='sans-serif')

    # Render to PIL Image
    buf = io.BytesIO()
    fig.savefig(buf, format='png', dpi=DPI, bbox_inches='tight', pad_inches=0.2)
    plt.close(fig)
    buf.seek(0)
    return Image.open(buf).convert('RGBA')


# --- Generate frames ---
frames_spec = [
    (0, 0, 0,
     "Phase 1: Planning Meeting",
     "Supervisor & student define the research vision, draft plan.md"),
    (0, 0, 0,
     "Phase 1: Planning Meeting",
     "Interactive — agree on scope, constraints, initial direction"),
    (1, 10, 10,
     "Phase 2: Deep Literature Review",
     "Student works autonomously — broad reading, landscape analysis"),
    (1, 10, 10,
     "Phase 2: Deep Literature Review",
     "Saves findings to notes.md and literature/"),
    (2, 10, 10,
     "Monday Check-in: Present Literature",
     "Slides: landscape, gaps, directions, questions for supervisor"),
    (2, 15, 15,
     "Monday Check-in: Supervisor Reviews",
     "Meeting mode — discuss directions, set velocity, approve plan"),
    (3, 20, 15,
     "Explore & Design (Mon→Tue)",
     "Literature search, refine question, design minimal PoC"),
    (3, 20, 15,
     "Explore & Design (Mon→Tue)",
     "THINKING only — no code, no experiments yet"),
    (4, 25, 20,
     "Wednesday Check-in: Present Findings",
     "Slides: findings, research question, proposed study, next steps"),
    (4, 25, 20,
     "Wednesday Check-in: Supervisor Approves",
     "Meeting mode — scope check, approve ONE concrete deliverable"),
    (5, 30, 30,
     "Build & Run (Wed→Sun)",
     "Step 3: Set up environment and code scaffolding"),
    (5, 30, 40,
     "Build & Run (Wed→Sun)",
     "Step 4: Get Something Working — end-to-end pipeline"),
    (5, 35, 50,
     "Build & Run (Wed→Sun)",
     "Step 5: Run the PoC study, collect results, generate plots"),
    (6, 40, 40,
     "Monday Check-in: Present Results",
     "Slides: what was built, results, hypotheses, next direction"),
    (6, 40, 40,
     "→ Cycle repeats with higher direction & velocity",
     "Each cycle narrows focus and accelerates toward the paper"),
]

print("Generating frames...")
frames = []
for spec in frames_spec:
    img = make_frame(*spec)
    frames.append(img)

# Save GIF
out_dir = os.path.dirname(os.path.abspath(__file__))
out_path = os.path.join(out_dir, 'workflow.gif')
frames[0].save(
    out_path,
    save_all=True,
    append_images=frames[1:],
    duration=[2500] * len(frames),  # 2.5s per frame
    loop=0,
    optimize=True,
)
print(f"Saved to {out_path}")
print(f"Size: {os.path.getsize(out_path) / 1024:.0f} KB")
