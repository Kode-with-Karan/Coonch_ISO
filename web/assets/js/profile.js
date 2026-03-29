
// Sample data
const userData = JSON.parse(localStorage.getItem("userloginData"));
let main_name = document.getElementById("main_name")
let main_email = document.getElementById("main_email")
let main_address = document.getElementById("main_address")
let username = document.getElementById("username")
let email = document.getElementById("email")
let mobile = document.getElementById("mobile")
let address = document.getElementById("address")
let website = document.getElementById("website")
let github = document.getElementById("github")
let twitter = document.getElementById("twitter")
let instagram = document.getElementById("instagram")
let facebook = document.getElementById("facebook")


// API endpoint
const apiUrl = 'http://127.0.0.1:5000/getinfo';

// Fetch options
const options = {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json'
        // You might need additional headers, such as authentication headers
    },
    body: JSON.stringify(userData)
};

// Send data to the API
fetch(apiUrl, options)
    .then(response => response.json())
    .then(data => {
        main_name.innerHTML = data.username;
        username.innerHTML = data.username;
        email.innerHTML = data.email;
        main_email.innerHTML = data.email;
        try {
            mobile.innerHTML = data.mobile;
            address.innerHTML = data.address;
            main_address.innerHTML = data.address;
            website.innerHTML = data.website;
            github.innerHTML = data.github;
            twitter.innerHTML = data.twitter;
            instagram.innerHTML = data.instagram;
            facebook.innerHTML = data.facebook;

        } catch (error) {
            console.log(error)
        }
    })
    .catch(error => {
        console.error('Error:', error);
    });