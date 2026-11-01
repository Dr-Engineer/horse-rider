"""The game's colour palette. docs/STYLE_GUIDE.md explains when to use each group."""

# Row 0 of the atlas. Grey multipliers for the per-instance slots A, B, C, D.
TEAM_CELLS = [
    ("a1", 255), ("a2", 196), ("a3", 150), ("a4", 110),   # slot A: robe
    ("b1", 255), ("b2", 196), ("b3", 150), ("b4", 110),   # slot B: trim, rug
    ("c1", 255), ("c2", 196), ("c3", 150), ("c4", 110),   # slot C: horse coat
    ("d1", 255), ("d2", 196), ("d3", 150), ("d4", 110),   # slot D: mane, tail, accent
]

COLORS = [
    ("white", "#FFFFFF"),
    # Inks and neutrals
    ("ink", "#17131A"), ("soot", "#2B2630"), ("charcoal", "#453D46"), ("slate", "#6B6570"),
    ("ash", "#9B9595"), ("bone", "#D9CDB2"), ("chalk", "#EFE6D2"), ("conch", "#FBF5E6"),
    # Mineral pigments
    ("vermilion", "#D63A22"), ("cinnabar", "#9E2418"), ("madder", "#7A1C22"), ("pema", "#6E2A25"),
    ("orpiment", "#F2B632"), ("gold", "#D9A227"), ("amber", "#C47A1A"), ("ochre", "#C9953F"),
    ("malachite", "#2E9E78"), ("malachite_dark", "#1B6B58"), ("turquoise", "#2FB7B0"), ("turquoise_light", "#7FD9CE"),
    ("lapis", "#1F4FA8"), ("lapis_deep", "#12306E"), ("azure", "#4A8FD9"), ("sky_pale", "#BFE0E8"),
    ("indigo", "#2A2A66"), ("saffron", "#E8871E"), ("plum", "#6B2F5B"), ("rose", "#D9697A"),
    # Earths
    ("umber", "#5A3D2B"), ("sienna", "#8C5A33"), ("tan", "#B98D5A"), ("sand", "#D8BE8E"), ("khaki", "#A89A63"),
    ("rock_red", "#9C4E36"), ("rock_grey", "#7D7A78"), ("rock_dark", "#544F52"), ("rock_purple", "#6F5A6B"),
    # Plants
    ("grass_gold", "#B6A94F"), ("grass_green", "#7E9A41"), ("grass_deep", "#4F7A3A"),
    ("pine", "#2F5540"), ("juniper", "#3C6B52"), ("barley", "#D9C75A"),
    # Snow and water
    ("snow", "#F6FBFF"), ("snow_shadow", "#BFD2E8"), ("ice", "#A8DCE8"), ("water_deep", "#17779B"),
    # Skin
    ("skin_light", "#D19A6E"), ("skin", "#B97F54"), ("skin_deep", "#96603C"), ("blush", "#B85A45"),
    # Materials
    ("wood_light", "#A8743F"), ("wood_dark", "#6A4427"), ("iron", "#4F5560"), ("steel", "#A9B4BF"),
    ("silver", "#D6DDE3"), ("brass", "#C9A441"), ("coral", "#E0603F"), ("amber_bead", "#E09A2B"),
    ("leather", "#6E4526"), ("sheepskin", "#E7DCC1"), ("fox_fur", "#C9722E"), ("yak_black", "#211C1F"),
    ("yak_brown", "#4A3526"), ("hair_black", "#1C171C"), ("felt_white", "#E4DCCB"),
]
