"""Generate an animated workflow GIF for ClautoResearch README."""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
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
PAPER_COLOR = '#f0883e'

# Phase boxes — onboarding + R&D loop + paper
PHASES = [
    {'name': 'Planning\nMeeting', 'color': PURPLE, 'icon': 'PLAN', 'x': 0.5, 'tag': 'onboard'},
    {'name': 'Deep Lit\nReview', 'color': ACCENT, 'icon': 'LIT', 'x': 1.7, 'tag': 'onboard'},
    {'name': 'Mon\nCheck-in', 'color': GREEN, 'icon': 'SLIDES', 'x': 3.1, 'tag': 'gate'},
    {'name': 'Explore &\nDesign', 'color': ACCENT, 'icon': 'R&D', 'x': 4.5, 'tag': 'work'},
    {'name': 'Wed\nCheck-in', 'color': GREEN, 'icon': 'SLIDES', 'x': 5.9, 'tag': 'gate'},
    {'name': 'Build &\nRun', 'color': ORANGE, 'icon': 'CODE', 'x': 7.3, 'tag': 'work'},
    {'name': 'Mon\nCheck-in', 'color': GREEN, 'icon': 'SLIDES', 'x': 8.7, 'tag': 'gate'},
    {'name': 'Write\nPaper', 'color': PAPER_COLOR, 'icon': 'PAPER', 'x': 10.1, 'tag': 'paper'},
]

BOX_Y = 2.8
BOX_W = 1.0
BOX_H = 1.2


def draw_base(fig, ax):
    """Draw the static workflow elements."""
    ax.set_xlim(-0.3, 11.5)
    ax.set_ylim(-1.5, 5.5)
    ax.set_facecolor(BG)
    fig.set_facecolor(BG)
    ax.axis('off')

    # Title
    ax.text(5.5, 5.0, 'ClautoResearch Workflow', fontsize=20, fontweight='bold',
            color=FG, ha='center', va='center', fontfamily='monospace')

    # Phase boxes
    for p in PHASES:
        x = p['x']
        rect = FancyBboxPatch((x - BOX_W/2, BOX_Y - BOX_H/2),
                              BOX_W, BOX_H,
                              boxstyle="round,pad=0.08",
                              facecolor=BOX_BG, edgecolor=BOX_BORDER, linewidth=1.5,
                              zorder=2)
        ax.add_patch(rect)
        ax.text(x, BOX_Y + 0.15, p['name'], fontsize=8, color=FG,
                ha='center', va='center', fontfamily='sans-serif', fontweight='bold',
                zorder=3)
        ax.text(x, BOX_Y - 0.4, p['icon'], fontsize=7, ha='center', va='center',
                color=p['color'], fontfamily='monospace', fontweight='bold', alpha=0.7,
                zorder=3)

    # Arrows between phases (onboarding → first Mon check-in)
    for i in range(len(PHASES) - 2):  # stop before last Mon→Paper
        x1 = PHASES[i]['x'] + BOX_W/2 + 0.02
        x2 = PHASES[i+1]['x'] - BOX_W/2 - 0.02
        ax.annotate('', xy=(x2, BOX_Y), xytext=(x1, BOX_Y),
                    arrowprops=dict(arrowstyle='->', color=DIMMED, lw=1.5),
                    zorder=1)

    # Dashed arrow from last Mon check-in to Paper (only when ready)
    x1 = PHASES[6]['x'] + BOX_W/2 + 0.02
    x2 = PHASES[7]['x'] - BOX_W/2 - 0.02
    ax.annotate('', xy=(x2, BOX_Y), xytext=(x1, BOX_Y),
                arrowprops=dict(arrowstyle='->', color=DIMMED, lw=1.5,
                               linestyle='dashed'),
                zorder=1)

    # Cycle loop arrow — draw ABOVE the boxes using a high arc
    ax.annotate('', xy=(PHASES[3]['x'], BOX_Y + BOX_H/2 + 0.12),
                xytext=(PHASES[6]['x'], BOX_Y + BOX_H/2 + 0.12),
                arrowprops=dict(arrowstyle='->', color=DIMMED, lw=1.5,
                               connectionstyle='arc3,rad=-0.35'),
                zorder=4)
    ax.text(6.1, 4.25, 'next cycle', fontsize=7, color=DIMMED,
            ha='center', va='center', fontstyle='italic', zorder=4)

    # Onboarding bracket
    bx0 = PHASES[0]['x'] - 0.55
    bx1 = PHASES[1]['x'] + 0.55
    by0 = BOX_Y - 0.7
    by1 = BOX_Y + 0.7
    ax.plot([bx0, bx0], [by0, by1], color=PURPLE, lw=1.5, alpha=0.5, zorder=1)
    ax.plot([bx0, bx1], [by1, by1], color=PURPLE, lw=1.5, alpha=0.5, zorder=1)
    ax.plot([bx1, bx1], [by0, by1], color=PURPLE, lw=1.5, alpha=0.5, zorder=1)
    ax.text(1.1, by1 + 0.25, 'onboarding (once)', fontsize=7, color=PURPLE,
            ha='center', va='center', fontstyle='italic', alpha=0.7)

    # Legend
    legend_y = -0.8
    items = [
        (ACCENT, 'Autonomous work'),
        (GREEN, 'Supervisor gate'),
        (ORANGE, 'Execution'),
        (PURPLE, 'Interactive meeting'),
        (PAPER_COLOR, 'Writing phase'),
    ]
    for i, (c, label) in enumerate(items):
        ax.plot(0.3 + i * 2.2, legend_y, 'o', color=c, markersize=5)
        ax.text(0.5 + i * 2.2, legend_y, label, fontsize=7, color=c,
                ha='left', va='center', fontfamily='sans-serif')


def draw_meter(ax, x, y, value, color, label):
    """Draw a labeled horizontal meter bar."""
    ax.text(x, y + 0.22, label, fontsize=7, color=FG, ha='center',
            fontfamily='sans-serif', fontweight='bold')
    bar_w = 0.8
    bar_h = 0.13
    bg = FancyBboxPatch((x - bar_w/2, y - bar_h/2), bar_w, bar_h,
                        boxstyle="round,pad=0.02", facecolor=BOX_BORDER, edgecolor='none')
    ax.add_patch(bg)
    fill_w = bar_w * (value / 100)
    if fill_w > 0.01:
        fill = FancyBboxPatch((x - bar_w/2, y - bar_h/2), fill_w, bar_h,
                              boxstyle="round,pad=0.02", facecolor=color,
                              edgecolor='none', alpha=0.8)
        ax.add_patch(fill)
    ax.text(x + bar_w/2 + 0.12, y, f'{value}%', fontsize=7, color=FG,
            ha='left', va='center')


def make_frame(step_idx, direction, velocity, description, detail, cycle_label=None):
    """Generate a single frame."""
    fig, ax = plt.subplots(figsize=(W, H))
    draw_base(fig, ax)

    # Highlight active phase
    for i, p in enumerate(PHASES):
        if i == step_idx:
            highlight = FancyBboxPatch(
                (p['x'] - BOX_W/2 - 0.04, BOX_Y - BOX_H/2 - 0.04),
                BOX_W + 0.08, BOX_H + 0.08,
                boxstyle="round,pad=0.08",
                facecolor='none', edgecolor=p['color'], linewidth=2.5, alpha=0.9,
                zorder=5)
            ax.add_patch(highlight)
            glow = FancyBboxPatch(
                (p['x'] - BOX_W/2 - 0.08, BOX_Y - BOX_H/2 - 0.08),
                BOX_W + 0.16, BOX_H + 0.16,
                boxstyle="round,pad=0.1",
                facecolor='none', edgecolor=p['color'], linewidth=1, alpha=0.3,
                zorder=5)
            ax.add_patch(glow)

    # Description panel
    desc_y = 0.3
    desc_rect = FancyBboxPatch((1.5, desc_y - 0.35), 8.0, 0.7,
                               boxstyle="round,pad=0.1",
                               facecolor=BOX_BG, edgecolor=BOX_BORDER, linewidth=1)
    ax.add_patch(desc_rect)

    # Cycle label (top-left of description)
    if cycle_label:
        ax.text(1.75, desc_y + 0.1, cycle_label, fontsize=8, color=DIMMED,
                ha='left', va='center', fontfamily='monospace')
        desc_x = 5.8
    else:
        desc_x = 5.5

    ax.text(desc_x, desc_y + 0.1, description, fontsize=10, color=FG,
            ha='center', va='center', fontweight='bold', fontfamily='sans-serif')
    ax.text(desc_x, desc_y - 0.15, detail, fontsize=8, color=DIMMED,
            ha='center', va='center', fontfamily='sans-serif')

    # Meters (bottom right area, below the Paper box)
    draw_meter(ax, 10.1, 1.4, direction, ACCENT, 'Direction')
    draw_meter(ax, 10.1, 0.7, velocity, ORANGE, 'Velocity')

    buf = io.BytesIO()
    fig.savefig(buf, format='png', dpi=DPI, bbox_inches='tight', pad_inches=0.2)
    plt.close(fig)
    buf.seek(0)
    return Image.open(buf).convert('RGBA')


# --- Frame definitions ---
# (step_idx, direction, velocity, description, detail, cycle_label, duration_ms)

frames = []

# === ONBOARDING ===
onboard = [
    (0, 0, 0, "Planning Meeting",
     "Supervisor & student define the research vision, draft plan.md", None, 3000),
    (0, 0, 0, "Planning Meeting",
     "Interactive — agree on scope, constraints, initial direction", None, 2500),
    (1, 5, 5, "Deep Literature Review",
     "Student works autonomously — broad reading, landscape analysis", None, 3000),
    (1, 5, 5, "Deep Literature Review",
     "Saves findings to notes.md and literature/", None, 2500),
]

# === R&D CYCLE 1 (slow — 2 frames per step) ===
c1_dir, c1_vel = 15, 10
cycle1 = [
    (2, c1_dir, c1_vel, "Monday Check-in",
     "Present literature findings, gaps, possible directions", "Cycle 1", 2500),
    (2, c1_dir, c1_vel, "Monday Check-in",
     "Meeting mode — supervisor sets direction, approves exploration", "Cycle 1", 2500),
    (3, c1_dir, c1_vel, "Explore & Design (Mon-Tue)",
     "Literature search, refine question, design minimal PoC", "Cycle 1", 2500),
    (3, c1_dir, c1_vel, "Explore & Design (Mon-Tue)",
     "THINKING only — no code, no experiments yet", "Cycle 1", 2500),
    (4, c1_dir, c1_vel, "Wednesday Check-in",
     "Present findings, proposed study, scoped next steps", "Cycle 1", 2500),
    (4, c1_dir, c1_vel, "Wednesday Check-in",
     "Supervisor approves ONE concrete deliverable for Wed-Sun", "Cycle 1", 2500),
    (5, c1_dir, c1_vel, "Build & Run (Wed-Sun)",
     "Set up environment, get pipeline working, run PoC study", "Cycle 1", 2500),
    (5, c1_dir, c1_vel, "Build & Run (Wed-Sun)",
     "Collect results, generate plots, save to results/", "Cycle 1", 2500),
]

# === R&D CYCLE 2 (medium — 1 frame per step) ===
c2_dir, c2_vel = 40, 35
cycle2 = [
    (2, c2_dir, c2_vel, "Monday Check-in",
     "Present last cycle's results, propose new direction", "Cycle 2", 2000),
    (3, c2_dir, c2_vel, "Explore & Design",
     "Narrower literature search, refine study design", "Cycle 2", 2000),
    (4, c2_dir, c2_vel, "Wednesday Check-in",
     "Tighter scope — the question is clearer now", "Cycle 2", 2000),
    (5, c2_dir, c2_vel, "Build & Run",
     "More ambitious execution — full training runs, ablations", "Cycle 2", 2000),
]

# === R&D CYCLE 3 (fast — 1 frame per step, shorter duration) ===
c3_dir, c3_vel = 70, 65
cycle3 = [
    (2, c3_dir, c3_vel, "Monday Check-in",
     "Strong results — direction is clear", "Cycle 3", 1500),
    (3, c3_dir, c3_vel, "Explore & Design",
     "Focused refinement — final experiment design", "Cycle 3", 1500),
    (4, c3_dir, c3_vel, "Wednesday Check-in",
     "Final study approved — go build the evidence", "Cycle 3", 1500),
    (5, c3_dir, c3_vel, "Build & Run",
     "Full experiments, sweeps, generate paper-ready figures", "Cycle 3", 1500),
]

# === PAPER WRITING ===
paper = [
    (6, 85, 80, "Results Ready",
     "Enough evidence collected — time to write", "Cycle 3", 2000),
    (7, 90, 85, "Writing Phase",
     "/write — draft the paper from accumulated results", None, 3000),
    (7, 90, 85, "Writing Phase",
     "Can drop back into R&D mini-cycles to fill gaps", None, 3000),
]

# === Build frame list with durations ===
all_specs = onboard + cycle1 + cycle2 + cycle3 + paper

print(f"Generating {len(all_specs)} frames...")
images = []
durations = []
for spec in all_specs:
    step_idx, d, v, desc, detail, clabel, dur = spec
    img = make_frame(step_idx, d, v, desc, detail, clabel)
    images.append(img)
    durations.append(dur)

# Save GIF
out_dir = os.path.dirname(os.path.abspath(__file__))
out_path = os.path.join(out_dir, 'workflow.gif')
images[0].save(
    out_path,
    save_all=True,
    append_images=images[1:],
    duration=durations,
    loop=0,
    optimize=True,
)
print(f"Saved to {out_path}")
print(f"Size: {os.path.getsize(out_path) / 1024:.0f} KB")
print(f"Frames: {len(images)}, total duration: {sum(durations)/1000:.1f}s")
