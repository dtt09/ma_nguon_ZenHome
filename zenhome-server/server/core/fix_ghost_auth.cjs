const { getAuth, db } = require('./firebase.cjs');

async function fix() {
    try {
        console.log("Checkingo for ghost Auth users...");
        // get all delete requests
        const snapshot = await db.collection('delete_requests').get();
        for (const doc of snapshot.docs) {
            const data = doc.data();
            const username = doc.id;
            const uid = data.uid;
            console.log(`Found delete_request for ${username} (UID: ${uid})`);
            
            if (uid) {
                try {
                    await getAuth().deleteUser(uid);
                    console.log(` Deleted Auth user: ${uid}`);
                } catch (e) {
                    console.log(`a Auth user ${uid} not found or already deleted.`);
                }
            }
            
            await db.collection('users').doc(username).delete();
            console.log(` Deleted Firestore user document for ${username}`);
            
            await doc.ref.delete();
            console.log(` Removed delete_request for ${username}`);
        }
        console.log("Done cleanup!");
        process.exit(0);
    } catch (e) {
        console.error("Error:", e);
        process.exit(1);
    }
}
fix();



