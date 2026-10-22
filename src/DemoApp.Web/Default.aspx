<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Default.aspx.cs" Inherits="DemoApp.Web.DefaultPage" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <title>CI/CD Demo</title>
    <style>
        body { font-family: Segoe UI, Arial, sans-serif; background: #f6f4ee; color: #14213d; margin: 0; }
        main { max-width: 760px; margin: 80px auto; padding: 0 24px; }
        h1 { font-size: 44px; margin-bottom: 24px; }
        .price { font-size: 28px; }
        .price strong { color: #b5491b; }
        footer { margin-top: 64px; font-family: Consolas, monospace; font-size: 20px; color: #4a5568; }
        .env { display: inline-block; padding: 4px 12px; border-radius: 999px; background: #14213d; color: #f6f4ee; }
    </style>
</head>
<body>
    <main>
        <h1><%: Headline %></h1>
        <p class="price">Price after a 10% discount on 100.00: <strong><%: DiscountedPrice %></strong></p>
        <footer>
            <span class="env"><%: EnvironmentName %></span>
            &nbsp; Version <%: Version %>
        </footer>
    </main>
</body>
</html>
