const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");

initializeApp();

exports.notifyOnPendingApproval = onDocumentCreated(
  { document: "approvalTasks/{taskId}", region: "us-central1" },
  async (event) => {
    const task = event.data?.data();
    if (!task || task.status !== "pending" || typeof task.ownerUID !== "string") return;

    const devices = await getFirestore()
      .collection("users").doc(task.ownerUID).collection("devices").get();
    const fids = [...new Set(devices.docs
      .map((doc) => doc.get("fid"))
      .filter((fid) => typeof fid === "string" && fid.length > 0))];

    if (fids.length === 0) {
      logger.info("No registered phone installations", { taskId: event.params.taskId });
      return;
    }

    // Keep lock-screen content generic; the app fetches the exact action from Firestore.
    const title = "Island Agent needs approval";
    const body = "A Mac action is waiting for your review.";
    const results = await Promise.allSettled(fids.map((fid) => getMessaging().send({
      fid,
      notification: { title, body },
      apns: { payload: { aps: { sound: "default" } } },
      data: { taskId: event.params.taskId, kind: "approval" }
    })));

    const failures = results.filter((result) => result.status === "rejected");
    if (failures.length) {
      logger.error("Some push notifications failed", {
        taskId: event.params.taskId,
        failureCount: failures.length
      });
      throw new Error(`Failed to send ${failures.length} notification(s)`);
    }
  }
);
