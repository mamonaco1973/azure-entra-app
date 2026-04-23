## Create Microsoft Entra External Tenant and Configure Application

1. Navigate to the **Microsoft Entra ID** blade in the Azure portal.
2. Select **Manage tenants**.
3. Select **Create**.
4. Select **External**.
5. Select **Continue**.
6. Specify the **Organization Name**, **Initial Domain Name**, **Subscription**, and **Resource Group**.
7. Record the **Initial Domain Name** for later input into environment variables.
8. Select **Review + create** and wait for the tenant deployment to complete.
9. Open the tenant resource in the resource group.
10. Record the **Tenant ID** for later input into environment variables.
11. Select **Switch directory**.
12. Switch to the new external tenant directory.

---

## Create User Flow

13. Navigate to the **Microsoft Entra ID** blade.
14. Select **External Identities**.
15. Select **User flows**.
16. Select **New user flow**.
17. Specify the **user flow name**.
18. Configure the sign-in method.
19. Select user attributes such as **Email Address** and **Display Name**.
20. Record the **User flow name** for later input into environment variables.
21. Select **Create** and wait for completion.

---

## Create App Registration

22. Navigate to **App registrations**.
23. Select **New registration**.
24. Specify the **application name**, then select **Register**.
25. Record the **Application (client) ID** for later input into environment variables.

---

## Create Client Secret

26. Select **Certificates & secrets**.
27. Select **New client secret**.
28. Specify a description, then select **Add**.
29. Record the **client secret value** for later input into environment variables.

---

## Configure API Permissions

30. Select **API permissions**.
31. Select **Add a permission**.
32. Select **Microsoft Graph**.
33. Select **Application permissions**.
34. Add the following permissions:
    - `EventListener.ReadWrite.All`
    - `Application.ReadWrite.All`
35. Select **Add permissions**.
36. Select **Grant admin consent**.

---

## Associate Application with User Flow

37. Navigate to **External Identities** > **User flows**.
38. Open the user flow created earlier.
39. Select **Applications**.
40. Select **Add application**.
41. Select the application registration created earlier and confirm.