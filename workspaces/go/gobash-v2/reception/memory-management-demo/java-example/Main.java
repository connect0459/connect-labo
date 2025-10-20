public class Main {
    // すべてのオブジェクトはヒープに確保される
    public static class Person {
        private String name;
        private int age;

        public Person(String name, int age) {
            this.name = name;
            this.age = age;
            System.out.printf("[Java] Person constructor: name=%s, age=%d (this=%s)%n",
                name, age, Integer.toHexString(System.identityHashCode(this)));
        }

        public String getName() { return name; }
        public int getAge() { return age; }
    }

    // オブジェクトを返す（Javaでは常にヒープ上の参照）
    public static Person createPerson() {
        Person p = new Person("太郎", 25);
        System.out.printf("[Java] createPerson: Person instance at %s%n",
            Integer.toHexString(System.identityHashCode(p)));
        return p; // 参照を返す（ヒープ上のオブジェクトを指す）
    }

    // 配列を返す（これもヒープに確保される）
    public static int[] createArray() {
        int[] arr = new int[10];
        arr[0] = 42;
        System.out.printf("[Java] createArray: array at %s%n",
            Integer.toHexString(System.identityHashCode(arr)));
        return arr; // 配列の参照を返す
    }

    // プリミティブ型は値渡し
    public static int createValue() {
        int x = 42;
        System.out.printf("[Java] createValue: x=%d (primitive value)%n", x);
        return x; // 値のコピー
    }

    // 参照を渡す（Javaでは引数もすべて値渡しだが、オブジェクトの場合は参照の値渡し）
    public static void modifyPerson(Person p) {
        System.out.printf("[Java] modifyPerson: received Person at %s%n",
            Integer.toHexString(System.identityHashCode(p)));
        // 参照先のオブジェクトは変更できる（これはSharing Downに相当）
        // ただし、参照自体は変更できない（値渡しなので）
    }

    // 大きなオブジェクト
    public static class LargeObject {
        private int[] data = new int[10000]; // 約40KB

        public LargeObject() {
            data[0] = 1;
            System.out.printf("[Java] LargeObject constructor: at %s%n",
                Integer.toHexString(System.identityHashCode(this)));
        }

        public int[] getData() { return data; }
    }

    public static void main(String[] args) {
        System.out.println("=== Java言語のメモリ管理デモ ===\n");

        // 1. オブジェクトの生成（すべてヒープ）
        System.out.println("--- 1. オブジェクトの生成: すべてヒープに確保される ---");
        Person person = createPerson();
        System.out.printf("[Java] main: received Person at %s, name=%s, age=%d%n",
            Integer.toHexString(System.identityHashCode(person)),
            person.getName(),
            person.getAge());
        System.out.println("[Java] ✓ Javaでは全てのオブジェクトがヒープに確保される");
        System.out.println("[Java] ✓ 関数から返しても問題なし（GCが自動管理）\n");

        // 2. 配列の生成（これもヒープ）
        System.out.println("--- 2. 配列の生成: ヒープに確保される ---");
        int[] arr = createArray();
        System.out.printf("[Java] main: received array at %s, arr[0]=%d%n",
            Integer.toHexString(System.identityHashCode(arr)), arr[0]);
        System.out.println("[Java] ✓ 配列もヒープ上のオブジェクト\n");

        // 3. プリミティブ型（値渡し）
        System.out.println("--- 3. プリミティブ型: 値渡し ---");
        int value = createValue();
        System.out.printf("[Java] main: received value=%d (copied)%n", value);
        System.out.println("[Java] ✓ プリミティブ型は値のコピー\n");

        // 4. 参照の値渡し（Sharing Downに相当）
        System.out.println("--- 4. 参照の値渡し: Sharing Downに相当 ---");
        Person p2 = new Person("花子", 30);
        System.out.printf("[Java] main: created Person at %s%n",
            Integer.toHexString(System.identityHashCode(p2)));
        modifyPerson(p2);
        System.out.println("[Java] ✓ 参照を渡すことで、呼び出し先で同じオブジェクトにアクセス可能\n");

        // 5. 大きなオブジェクト
        System.out.println("--- 5. 大きなオブジェクト: ヒープに確保、参照のみコピー ---");
        LargeObject lo = new LargeObject();
        System.out.printf("[Java] main: LargeObject at %s, data[0]=%d%n",
            Integer.toHexString(System.identityHashCode(lo)),
            lo.getData()[0]);
        System.out.println("[Java] ✓ 大きなオブジェクトも参照のコピーのみ（効率的）\n");

        // 6. ガベージコレクション
        System.out.println("--- 6. ガベージコレクション ---");
        System.out.println("[Java] ✓ 不要になったオブジェクトは自動的にGCが回収");
        System.out.println("[Java] ✓ プログラマは明示的なメモリ解放不要");
        System.out.println("[Java] ✓ すべてヒープなので、Cのようなダングリングポインタ問題は発生しない\n");

        // 7. JavaとGoの比較
        System.out.println("--- 7. JavaとGoの違い ---");
        System.out.println("[Java] 💡 Java: すべてのオブジェクトがヒープ（シンプル、GC必須）");
        System.out.println("[Java] 💡 Go: エスケープ解析で自動判断（スタック/ヒープ、効率的）");
        System.out.println("[Java] 💡 両方とも安全だが、Goの方がメモリ効率は高い傾向\n");

        System.out.println("=== デモ終了 ===");
    }
}
