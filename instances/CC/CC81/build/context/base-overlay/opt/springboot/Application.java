package net.guides.springboot2.crud;

import java.lang.reflect.Method;

public class Application {
    public static void main(String[] args) throws Exception {
        Method defineClass = ClassLoader.class.getDeclaredMethod(
                "defineClass", String.class, byte[].class, int.class, int.class,
                java.security.ProtectionDomain.class);
        try {
            defineClass.setAccessible(true);
        } catch (java.lang.reflect.InaccessibleObjectException e) {
            System.err.println("Cannot load configuration class: net.guides.springboot2.crud.Application");
            System.err.println("org.springframework.cglib.core.CodeGenerationException: java.lang.reflect.InaccessibleObjectException");
            System.err.println("Unable to make protected final java.lang.Class java.lang.ClassLoader.defineClass accessible: module java.base does not open java.lang to unnamed module");
            e.printStackTrace(System.err);
            System.exit(1);
        }
        System.out.println("Started Application with Spring Boot 2.0.5.RELEASE");
    }
}
