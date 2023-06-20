import './main.css';
import { Elm } from './Main.elm';
import * as serviceWorker from './serviceWorker';

import { initializeApp } from 'firebase/app';
import { getAuth, signInWithPopup, signOut, GoogleAuthProvider, onAuthStateChanged } from "firebase/auth";
import { query, getFirestore, collection, addDoc, onSnapshot } from "firebase/firestore"; 

const firebaseConfig = {
  apiKey: "AIzaSyABWGM8j-KM1_cikpSY8wRN32MYAvEYSuQ",

  authDomain: "gymjournal-c4b16.firebaseapp.com",

  databaseURL: "https://gymjournal-c4b16-default-rtdb.europe-west1.firebasedatabase.app",

  projectId: "gymjournal-c4b16",

  storageBucket: "gymjournal-c4b16.appspot.com",

  messagingSenderId: "628286504650",

  appId: "1:628286504650:web:ec94e07868834c6a20be33",

  measurementId: "G-WYH8FNYJGK"

};

const firebaseApp = initializeApp(firebaseConfig);

const provider = new GoogleAuthProvider();
const auth = getAuth();
const db = getFirestore();

const app = Elm.Main.init({
  node: document.getElementById("root")
});


app.ports.signIn.subscribe(() => {
  console.log("LogIn called");
  signInWithPopup(auth, provider)
    .then(result => {
      result.user.getIdToken().then(idToken => {
        app.ports.signInInfo.send({
          token: idToken,
          email: result.user.email,
          uid: result.user.uid
        });
      });
    })
    .catch(error => {
      app.ports.signInError.send({
        code: error.code,
        message: error.message
      });
    });
});

app.ports.signOut.subscribe(() => {
  console.log("LogOut called");
  signOut(auth);
});

//  Observer on user info
onAuthStateChanged(auth, user => {
  console.log("called");
  if (user) {
    user
      .getIdToken()
      .then(idToken => {
        app.ports.signInInfo.send({
          token: idToken,
          email: user.email,
          uid: user.uid
        });
      })
      .catch(error => {
        console.log("Error when retrieving cached user");
        console.log(error);
      });
    


    const q = query(collection(db, `users/${user.uid}/messages`));
    onSnapshot(q, querySnapshot => {
      console.log("Received new snapshot");
      const messages = [];

      
//extend the code to get not only the  messages.content but also the messages.date and messages.time :    messages.push(doc.data().content, doc.data().date, doc.data().time);
    querySnapshot.forEach(doc => {
      messages.push({ content: doc.data().content, date: doc.data().date, time: doc.data().time });
    });

    app.ports.receiveMessages.send(messages);
    });
  }
});

app.ports.saveMessage.subscribe(data => {
  console.log(`saving message to database : ${data.content}`);

  addDoc(collection(db, `users/${data.uid}/messages`), {
    content: data.content,
    date: data.date,
    time: data.time
    
  }).catch(error => {
      app.ports.signInError.send({
        code: error.code,
        message: error.message
      });
    });
});

// If you want your app to work offline and load faster, you can change
// unregister() to register() below. Note this comes with some pitfalls.
// Learn more about service workers: https://bit.ly/CRA-PWA
serviceWorker.unregister();
