export const ACTIVE_INDEX = Object.freeze({ Conjunction: 0, "<-+": 0, "+->": 1 });
export const ACTIVE_PATH_NODE_NAMES = Object.freeze([
    "Answer",
    "Bounced",
    "Conjunction",
    "Delay",
    "Freshened",
    "Goal-Conj",
    "Goal-Delay",
    "Goal-Disj",
    "+->",
    "<-+",
]);

export function addColors(tree) {

    const TERMINALS1   = new Set(["Answer", "Succeed", "Empty"]);
    const TERMINALS2   = new Set(["Answer", "Succeed"]);
    const DISJ         = new Set(["<-+", "+->"]);
    const SPINE        = new Set(["Answer", "Freshened", "Bounced"]);

    const activeChild = n => {
        if (!n) return null;
        const idx = ACTIVE_INDEX[n.name];
        return idx == null ? null : (n.children?.[idx] ?? null);
    };

    const rootColor = node => {
        if (!node) return null;
        if (DISJ.has(node.name) || node.name === "Goal-Disj") return "#ff8000";
        if (node.name === "Conjunction" || node.name === "Goal-Conj") return "blue";
        if (SPINE.has(node.name)) return rootColor(node.children?.[0] ?? null);
        if (node.name === "Delay" || node.name === "Goal-Delay") {
            return rootColor(node.children?.[0] ?? null);
        }
        return null;
    };

    function shouldDescend(node) {
        if (node.sub && node.name !== "Answer") return false;
        const d1 = activeChild(node);
        const d2 = activeChild(d1);
        if (DISJ.has(node?.name) && d1?.name === "Conjunction") return true;
        if (DISJ.has(node?.name) && DISJ.has(d1?.name) && d2 && TERMINALS2.has(d2.name)) return true;
        if (d1 && TERMINALS1.has(d1.name)) return false;
        if (d2 && TERMINALS2.has(d2.name)) return false;
        return true;
    }

    if (tree.partial) return tree;

    const children = tree.children;

    switch (tree.name) {
        case "<-+":
            children[0].color = "#ff8000";
            if (shouldDescend(tree)) addColors(children[0]);
            break;
        case "+->":
            children[1].color = "#ff8000";
            if (shouldDescend(tree)) addColors(children[1]);
            break;
        case "Disjunction":
            children[0].color = "#FFA500";
            if (shouldDescend(tree)) addColors(children[0]);
            break;
        case "Conjunction":
            children[0].color = "blue";
            if (shouldDescend(tree)) addColors(children[0]);
            break;
        case "Delay":
        case "Goal-Delay":
            if (children?.[0]) {
                tree.color = tree.color ?? rootColor(children[0]) ?? tree.color;
                children[0].color = tree.color;
                addColors(children[0]);
            }
            break;
        case "Answer":
        case "Freshened":
        case "Bounced":
            if (children) {
                tree.color = rootColor(children[0]) ?? (tree.name === "Answer" ? "green" : undefined);
                children[0].color = tree.color;
                addColors(children[0]);
            }
            break;
        default: return tree;
    }

    return tree;
}
