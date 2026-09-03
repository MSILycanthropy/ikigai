.pragma library

// Rank items against a query. Each item carries `terms`: [primary, ...secondary] lowercase
// strings. Tiers: prefix of the primary > prefix of any word > substring > subsequence.
function rank(query, items, limit) {
    const q = query.toLowerCase().trim();
    if (!q)
        return [];
    return items
        .map(item => ({ item: item, score: scoreItem(q, item.terms) }))
        .filter(r => r.score > 0)
        .sort((a, b) => b.score - a.score || a.item.name.length - b.item.name.length || a.item.name.localeCompare(b.item.name))
        .slice(0, limit)
        .map(r => r.item);
}

function scoreItem(q, terms) {
    let best = 0;
    terms.forEach((term, i) => {
        const weight = i === 0 ? 1 : 0.5;
        best = Math.max(best, scoreTerm(q, term) * weight);
    });
    return best;
}

function scoreTerm(q, term) {
    if (term.startsWith(q))
        return 1000 - term.length;
    if (term.split(/[\s\-_]+/).some(word => word.startsWith(q)))
        return 800 - term.length;
    if (term.includes(q))
        return 600 - term.indexOf(q);
    return subsequence(q, term);
}

function subsequence(q, term) {
    let score = 400, at = 0;
    for (const ch of q) {
        const next = term.indexOf(ch, at);
        if (next < 0)
            return 0;
        score -= next - at;
        at = next + 1;
    }
    return Math.max(score, 1);
}
