#!/usr/bin/env bb

(ns delete-resource-groups
  (:require [clojure.java.shell :refer [sh]]
            [clojure.string :as str]))

(defn die [msg]
  (binding [*out* *err*]
    (println msg))
  (System/exit 1))

(defn run! [& args]
  (let [res (apply sh args)]
    (when-not (zero? (:exit res))
      (binding [*out* *err*]
        (println "Command failed:" (str/join " " args))
        (when (seq (:err res))
          (println (:err res))))
      (System/exit (:exit res)))
    (:out res)))

(defn yes? [args]
  (some #{"--yes" "-y"} args))

(let [[subscription & args] *command-line-args*]
  (when-not subscription
    (die "Usage: delete-resource-groups.bb <subscription-id> [--yes]"))

  (run! "az" "account" "set" "--subscription" subscription)

  (let [resource-groups (-> (run! "az" "group" "list" "--subscription" subscription "--query" "[].name" "-o" "tsv")
                            str/split-lines
                            vec)]
    (when (empty? resource-groups)
      (println "No resource groups found.")
      (System/exit 0))

    (println "About to delete these resource groups:")
    (doseq [rg resource-groups]
      (println " - " rg))

    (when-not (yes? args)
      (println)
      (println "Type DELETE to continue:")
      (when-not (= "DELETE" (str/trim (or (read-line) "")))
        (die "Aborted.")))

    (doseq [rg resource-groups]
      (println "Deleting" rg)
      (run! "az" "group" "delete" "-n" rg "--subscription" subscription "--yes"))

    (println "Done.")))
