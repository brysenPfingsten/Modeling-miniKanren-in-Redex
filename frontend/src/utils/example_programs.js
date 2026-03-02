const appendo = `(defrel (appendo l s out)
  (conde
    [(== l '())
    (== s out)]
    [(fresh (a d res)
      (== l (cons a d))
      (== out (cons a res))
      (appendo d s res))]
  ))

(run* (q) (appendo (list 'minikanren) (list 'visualizer) q))`;

const appendoh1 = `(defrel (appendoh l s out)
  (conde
   [(== l '()) (== s out)]
   [(fresh (a d res)
      (== l (cons a d))
      (== out (cons a res))
      (appendoh d s out))]))

(run* (q) (appendoh '(dog) q '(dog cat)))`

const appendoh2 = `(defrel (appendoh l s out)
  (conde
   [(== l '()) (== s out)]
   [(fresh (a d res)
      (appendoh d s res)
      (== l (cons a d))
      (== out (cons a res)))]))

(run* (q r s) (appendoh q r s))`

const same = `(defrel (same x y)
  (== x y))

(run* (q)
  (conde
    [(conde
       [(same q 'turtle)]
       [(same q 'cat)]
       [(== q 'dog)])]
    [(same q 'fish)]))`

const div3o = `(defrel (same-counto bn)
  (conde
   [(== bn \`(1 1))]
   [(fresh (a ad dd)
      (== \`(,a ,ad . ,dd) bn)
      (conde
       [(== a ad) (same-counto dd)]
       [(== \`(,a ,ad) '(1 0)) (mod+1o dd)]
       [(== \`(,a ,ad) '(0 1)) (mod+2o dd)]))]))

(defrel (mod+1o bn)
  (conde
   [(== bn \`(0 1))]
   [(fresh (a ad dd)
      (== \`(,a ,ad . ,dd) bn)
      (conde
       [(== a ad) (mod+1o dd)]
       [(== \`(,a ,ad) '(1 0)) (mod+2o dd)]
       [(== \`(,a ,ad) '(0 1)) (same-counto dd)]))]))

(defrel (mod+2o bn)
  (conde
   [(== bn '(1))]
   [(fresh (a ad dd)
      (== \`(,a ,ad . ,dd) bn)
      (conde
       [(== a ad) (mod+2o dd)]
       [(== \`(,a ,ad) '(1 0)) (same-counto dd)]
       [(== \`(,a ,ad) '(0 1)) (mod+1o dd)]))]))

(defrel (multiple-of-threeo bn)
  (conde
   [(== bn '())]
   [(same-counto bn)]))

(run* (q) (multiple-of-threeo q))`

const fivesFours = `(defrel (fives x)
  (conde
    [(fives x)]
    [(== x 'five)]))

(defrel (fours x)
  (conde
    [(fours x)]
    [(== x 'four)]))

(run 8 (q)
  (conde
    [(fives q)]
    [(fours q)]))`

const callTiming = `(defrel (id x y)
  (== x y))

(run 3 (q)
  (id q 'ok))`

const ALL_MODELS = [
  "microKanren",
  "microKanren-rail",
  "microKanren-noi-flip",
  "microKanren-rail-eager",
  "microKanren-flip",
  "microKanren-flip-eager",
  "dmitry",
  "dfs",
];

export const exampleProgs = [
  { value: "", label: "Examples", models: ALL_MODELS },
  { value: appendo, label: "appendo", models: ALL_MODELS },
  { value: appendoh1, label: "appendoh 1", models: ALL_MODELS },
  { value: appendoh2, label: "appendoh 2", models: ALL_MODELS },
  { value: fivesFours, label: "fives/fours", models: ALL_MODELS },
  { value: callTiming, label: "call timing", models: ALL_MODELS },
  { value: same, label: "same", models: ALL_MODELS },
  { value: div3o, label: "div3o", models: ALL_MODELS },
];

export function examplesForModel(model) {
  if (!model) return exampleProgs;
  return exampleProgs.filter((opt) => (opt.models || []).includes(model));
}
