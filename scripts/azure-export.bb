#!/usr/bin/env bb

(ns azure-export
  (:require [clojure.java.io :as io]
            [clojure.java.shell :refer [sh]]
            [clojure.string :as str]))

(defn die [msg]
  (binding [*out* *err*]
    (println msg))
  (System/exit 1))

(defn ensure-dir! [path]
  (.mkdirs (io/file path)))

(defn run! [& args]
  (let [res (apply sh args)]
    (when-not (zero? (:exit res))
      (binding [*out* *err*]
        (println "Command failed:" (str/join " " args))
        (when (seq (:err res))
          (println (:err res))))
      (System/exit (:exit res)))
    (:out res)))

(defn maybe-run! [& args]
  (let [res (apply sh args)]
    (when-not (zero? (:exit res))
      (binding [*out* *err*]
        (println "Warning: command failed:" (str/join " " args))
        (when (seq (:err res))
          (println (:err res)))))
    res))

(defn export-resource-group! [sub out-dir rg]
  (let [rg-dir (str (io/file out-dir rg))
        template-json (str (io/file rg-dir "template.json"))]
    (println "Exporting" rg)
    (ensure-dir! rg-dir)
    (spit template-json
          (run! "az" "group" "export" "-n" rg "--subscription" sub "-o" "json"))
    (let [bicep-check (sh "bash" "-lc" "command -v bicep >/dev/null 2>&1")]
      (when (zero? (:exit bicep-check))
        (let [res (maybe-run! "bicep" "decompile" template-json "--outfile" (str (io/file rg-dir "main.bicep")))]
          (when (zero? (:exit res))
            true))))
    true))

(let [[sub out-dir & _] *command-line-args*
      out-dir (or out-dir "azure-export")]
  (when-not sub
    (die "Usage: azure-export.bb <subscription-id> [output-dir]"))

  (ensure-dir! out-dir)
  (println "Exporting Azure inventory")
  (spit (str (io/file out-dir "all-resources.json"))
        (run! "az" "resource" "list" "--subscription" sub "-o" "json"))

  (let [resource-groups (-> (run! "az" "group" "list" "--subscription" sub "--query" "[].name" "-o" "tsv")
                            str/split-lines)
        failures (atom [])]
    (doseq [rg resource-groups]
      (try
        (export-resource-group! sub out-dir rg)
        (catch Exception _
          (swap! failures conj rg))))
    (when (seq @failures)
      (binding [*out* *err*]
        (println "Some resource groups failed to export:" (str/join ", " @failures)))
      (System/exit 1))))
