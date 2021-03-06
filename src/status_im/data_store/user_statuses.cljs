(ns status-im.data-store.user-statuses
  (:require [clojure.string :as string]
            [re-frame.core :as re-frame]
            [status-im.data-store.realm.core :as core]))

(defn- prepare-statuses [statuses]
  (reduce (fn [acc {:keys [message-id public-key] :as user-status}]
            (assoc-in acc
                      [message-id public-key]
                      (-> user-status
                          (update :status keyword)
                          (dissoc :status-id))))
          {}
          statuses))

(defn- get-by-chat-and-messages-ids
  [chat-id message-ids]
  (-> @core/account-realm
      (.objects "user-status")
      (.filtered (str "chat-id=\"" chat-id "\""
                      (when (seq message-ids)
                        (str " and (" (core/in-query "message-id" message-ids) ")"))))
      (core/all-clj :user-status)
      prepare-statuses))

(re-frame/reg-cofx
 :data-store/get-user-statuses
 (fn [cofx _]
   (assoc cofx :get-stored-user-statuses get-by-chat-and-messages-ids)))

(defn- compute-status-id [{:keys [message-id public-key]}]
  (str message-id "-" public-key))

(defn save-status-tx
  "Returns tx function for saving message user status"
  [user-status]
  (fn [realm]
    (let [status-id (compute-status-id user-status)]
      (core/create realm :user-status (assoc user-status :status-id status-id) true))))

(defn save-statuses-tx
  "Returns tx function for saving message user statuses"
  [user-statuses]
  (fn [realm]
    (doseq [user-status user-statuses]
      ((save-status-tx user-status) realm))))
