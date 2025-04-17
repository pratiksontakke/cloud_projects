Okay, Pratik, let's create a clear and effective README specifically for your frontend application (Vite/React/TS). This README will guide you or anyone else on setting up the frontend locally and testing it against your deployed AWS backend infrastructure.

---

# Project 1 - Frontend Application (React/Vite/TypeScript)

This project contains the frontend user interface built with React, Vite, TypeScript, shadcn-ui, and Tailwind CSS. It interacts with the backend API deployed on the AWS infrastructure defined in Project 1.

## Prerequisites

Before you begin, ensure you have the following installed:

1.  **Node.js and npm:** >= v18 recommended. ([Install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating)).
2.  **Git:** For cloning the repository.
3.  **Deployed Backend:** The AWS infrastructure from Project 1 (ALB, ASG, EC2, RDS) must be deployed and running successfully.
4.  **Backend API URL:** You need the DNS name of your Application Load Balancer (ALB). You can get this from the Terraform output:
    ```bash
    terraform output alb_dns_name
    ```

## Getting Started

1.  **Clone the Repository:**
    ```bash
    # Navigate to where you want to store the project
    git clone https://github.com/pratiksontakke/cloud_projects.git
    ```

2.  **Navigate to Frontend Directory:**
    ```bash
    cd cloud_projects/project_001 # Or the specific directory containing the frontend's package.json
    ```
    *(**Note:** Adjust the `cd` command if your frontend code lives in a different subdirectory like `frontend/`)*

3.  **Install Dependencies:**
    ```bash
    npm install
    ```

## Configuration - Connecting to the Backend

This frontend needs to know the URL of your deployed backend API. We use environment variables for this, managed via a `.env.local` file (which overrides other `.env` files and is *not* committed to Git).

1.  **Create `.env.local` File:** In the frontend project's root directory (where `package.json` is), create a file named `.env.local`.

2.  **Add API Base URL:** Add the following line to `.env.local`, replacing `<YOUR_ALB_DNS_NAME>` with the actual DNS name of your ALB (including `http://` or `https://` depending on your setup):

    ```dotenv
    # .env.local - Configure for your deployed backend

    # Base URL for the backend API deployed on AWS ALB
    # IMPORTANT: Use http:// if your ALB listener is HTTP (Port 80)
    #          Use https:// if your ALB listener is HTTPS (Port 443)
    VITE_API_BASE_URL=http://<YOUR_ALB_DNS_NAME>
    ```
    *Example:* `VITE_API_BASE_URL=http://project01-alb-1234567890.ap-south-1.elb.amazonaws.com`

3.  **How it's Used (Conceptual):** Somewhere in your frontend code (e.g., in an API service file or where you use `fetch`/`axios`), the base URL for API calls should be read from this environment variable:
    ```typescript
    // Example in an api.ts or similar service file
    const API_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080'; // Fallback for safety

    // Example fetch call
    fetch(`${API_URL}/api/tutorials`)
      .then(response => response.json())
      .then(data => console.log(data));
    ```
    *(**Note:** You'll need to ensure your React code actually uses `import.meta.env.VITE_API_BASE_URL` when making API calls.)*

## Running Locally for Development

1.  **Start the Vite Dev Server:**
    ```bash
    npm run dev
    ```
2.  **Access the Frontend:** Open your web browser and navigate to the URL provided by Vite (usually `http://localhost:5173`).

Your frontend application should now be running locally, but making API calls to your live AWS backend specified in `.env.local`.

## Testing All Backend Endpoints

You can test the integration with the backend API in several ways:

**Method 1: Using the Frontend UI**

This is the primary way to test the end-to-end flow.

1.  **Run the frontend locally** (`npm run dev`).
2.  **Open Browser Dev Tools:** Open your browser's developer console (usually F12) and switch to the "Network" tab. This allows you to see the actual HTTP requests being made to your backend API.
3.  **Perform UI Actions:**
    *   **Load Data (GET /api/tutorials):** Does the main list/table load data from the backend? Check the Network tab for a request to `http://<YOUR_ALB_DNS_NAME>/api/tutorials` and ensure it gets a `200 OK` status.
    *   **Create Data (POST /api/tutorials):** Try creating a new tutorial using your UI's form. Check the Network tab for a `POST` request. Did it get a `201 Created` or `200 OK`? Does the new item appear in the UI?
    *   **View/Edit Data (GET /api/tutorials/:id, PUT /api/tutorials/:id):** Try viewing details or editing an existing tutorial. Check the Network tab for `GET` and `PUT` requests. Did they succeed? Are the changes reflected?
    *   **Delete Data (DELETE /api/tutorials/:id):** Try deleting a tutorial. Check the Network tab for a `DELETE` request. Did it succeed (`200 OK` or `204 No Content`)? Is the item removed from the UI?
    *   **Health Check (GET /health):** While the UI might not hit this directly, it confirms basic API reachability.

**Method 2: Using `curl` or API Client (Postman/Insomnia)**

This method tests the backend API directly, bypassing the frontend UI. Replace `<YOUR_ALB_DNS_NAME>` and use appropriate IDs.

1.  **Health Check:**
    ```bash
    curl http://<YOUR_ALB_DNS_NAME>/health
    # Expected: {"message":"Application health is good."}
    ```

2.  **Get All Tutorials:**
    ```bash
    curl http://<YOUR_ALB_DNS_NAME>/api/tutorials
    # Expected: JSON array of tutorials or empty array []
    ```

3.  **Create a Tutorial:**
    ```bash
    curl -X POST http://<YOUR_ALB_DNS_NAME>/api/tutorials \
         -H "Content-Type: application/json" \
         -d '{"title": "Test via Curl", "description": "Testing POST endpoint"}'
    # Expected: JSON response with the created tutorial and its ID
    ```

4.  **Get Specific Tutorial (Replace `:id`):**
    ```bash
    curl http://<YOUR_ALB_DNS_NAME>/api/tutorials/1
    # Expected: JSON object for tutorial with ID 1
    ```

5.  **Update a Tutorial (Replace `:id`):**
    ```bash
    curl -X PUT http://<YOUR_ALB_DNS_NAME>/api/tutorials/1 \
         -H "Content-Type: application/json" \
         -d '{"title": "Updated via Curl", "description": "Testing PUT endpoint", "published": true}'
    # Expected: JSON object with updated tutorial data or success message
    ```

6.  **Delete a Tutorial (Replace `:id`):**
    ```bash
    curl -X DELETE http://<YOUR_ALB_DNS_NAME>/api/tutorials/1
    # Expected: Success message or empty response with status 200/204
    ```

**Troubleshooting Tips:**

*   **CORS Errors:** If requests from your `localhost:5173` frontend are blocked, check the browser console for CORS errors. Ensure your backend (`server.js` corsOptions or the `*` setting in the `.env` file created by User Data) allows requests from your frontend origin or is set to `*` for testing. The User Data script currently sets `CORS_ORIGIN=*`, which should allow localhost access.
*   **Network Errors:** Check the Network tab in browser dev tools for failed requests (non-2xx status codes). Look at the response body for error details from the backend API.
*   **Backend Logs:** If API calls fail, check the backend application logs using `pm2 logs webapp-dev` (via SSH) for detailed error messages (database errors, code exceptions, etc.).

## Building for Production

To create an optimized static build of the frontend:

```bash
npm run build
```

This will generate a `dist` folder containing the static HTML, CSS, and JavaScript files ready for deployment.

## Deployment

While this README focuses on local development and testing, the production build output in the `dist` folder can be deployed to static hosting services like:

*   **AWS S3 + CloudFront:** Standard AWS approach for hosting static websites globally with CDN caching.
*   **Lovable:** As mentioned in the original README snippet ([Setting up a custom domain](https://docs.lovable.dev/tips-tricks/custom-domain#step-by-step-guide)).
*   Other services like Netlify, Vercel, etc.

---

This README should provide a clear guide for working with the frontend and ensuring it integrates correctly with your deployed backend API. Remember to replace placeholders with your actual values.