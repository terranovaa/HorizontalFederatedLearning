package it.unipi.dsmt.horizontalFederatedLearning.servlet;

import javax.servlet.*;
import javax.servlet.http.*;
import javax.servlet.annotation.*;
import java.io.IOException;
import it.unipi.dsmt.horizontalFederatedLearning.entities.User;
import it.unipi.dsmt.horizontalFederatedLearning.service.db.*;
import it.unipi.dsmt.horizontalFederatedLearning.service.exceptions.LoginException;

@WebServlet(name = "Login", value = "/Login")
public class Login extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String targetJSP = "/pages/jsp/login.jsp";
        RequestDispatcher requestDispatcher = request.getRequestDispatcher(targetJSP);
        requestDispatcher.forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String username = request.getParameter("username");
        String password = request.getParameter("password");
        try {
            UserService.login(username, password);
            User myUser = UserService.findUserByUsername(username);
            if(myUser != null && myUser.getAdmin()) {
                HttpSession session = request.getSession();
                session.setAttribute("isAdmin", true);
                session.setAttribute("user", myUser.getId());
                response.sendRedirect(request.getContextPath() + "/AdminPage");
            } else {
                HttpSession session = request.getSession();
                session.setAttribute("user", myUser.getId());
                response.sendRedirect(request.getContextPath() + "/Home");
            }
        } catch (LoginException e) {
            request.setAttribute("error", e.getMessage());
            String targetJSP = "/pages/jsp/login.jsp";
            RequestDispatcher requestDispatcher = request.getRequestDispatcher(targetJSP);
            requestDispatcher.forward(request, response);
        }
    }
}
