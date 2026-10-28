package example;

public class App {
    public static void main(String[] args) throws Exception {
        Class.forName("org.springframework.orm.hibernate5.SpringSessionContext");
        System.out.println("SpringSessionContext loaded successfully");
    }
}
